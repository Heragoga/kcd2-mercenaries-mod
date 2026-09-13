"""Run real builder functions in LuaJIT, with only engine calls stubbed."""
import json
import math
from pathlib import Path
from lupa.luajit21 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('mercenaries={DevCommand=function() end}; System={LogAlways=function() end}; Script={LoadScript=function() end}')
lua.execute((ROOT/'data/Scripts/mods/mercenaries_wall.lua').read_text(encoding='utf-8-sig'))
lua.execute((ROOT/'data/Scripts/mods/mercenaries_castle.lua').read_text(encoding='utf-8-sig'))
m=lua.globals().mercenaries
m.WallTypeIdx=m.CastleWallBase+1
m.WallUp=0;m.WallSnap=False;m.CastleTowerEvery=1

def point(x,y):return lua.table_from({'x':x,'y':y,'z':0})
def run(points,closed=False):return lua.table_from({'pts':lua.table_from([point(*p) for p in points]),'closed':closed})

def plain(t):
    if hasattr(t,'items'):return {str(k):plain(v) for k,v in t.items()}
    return t

count=0;out=[]
for yaw in [0,math.pi/4,math.pi/2,math.pi,3*math.pi/2]:
    cs,sn=math.cos(yaw),math.sin(yaw)
    pts=[(x*cs-y*sn,x*sn+y*cs) for x,y in [(0,0),(24,0),(24,24),(0,24)]]
    r=run(pts,True)
    for i in range(1,5):
        pl=m.CastleVertexPlan(m,r,i)
        assert pl.kind=='tower' and pl.cut==4
        a=r.pts[i];p=r.pts[(i-2)%4+1];n=r.pts[i%4+1]
        for other in [p,n]:
            angle=math.atan2(other.y-a.y,other.x-a.x)
            rear=pl.yaw+math.pi/2
            assert math.cos(rear-angle)<.7,'Blind stair bay faces a connecting wall'
        center=(a.x+(pl.dx or 0),a.y+(pl.dy or 0))
        gx=center[0]+1.82*math.cos(pl.yaw)+3.8*math.sin(pl.yaw)
        gy=center[1]+1.82*math.sin(pl.yaw)-3.8*math.cos(pl.yaw)
        # Rotate the actual ground door back into this square's coordinates.
        ux,uy=gx*cs+gy*sn,-gx*sn+gy*cs
        assert 0<ux<24 and 0<uy<24,'Ground entrance is outside courtyard'
        j=i%4+1
        segs=m.WallEdgeSegments(m,a,r.pts[j],True,4,4)
        assert len(segs)==4
        for k in range(1,len(segs)):
            q1,q2=segs[k].pos,segs[k+1].pos
            assert abs(math.hypot(q2.x-q1.x,q2.y-q1.y)-4)<1e-6
        count+=1
        if yaw==0:out.append({'vertex':plain(a),'tower':plain(pl),'segments':plain(segs)})

# Ends, absence of towers, oblique corners, and the taller hand-wall model.
r=run([(0,0),(24,0)])
for i in [1,2]:assert m.CastleVertexPlan(m,r,i).cut==4
m.CastleTowerEnds=False
assert m.CastleVertexPlan(m,r,1) is None
m.CastleTowerEnds=True
for angle in [45,135]:
    r=run([(-20,0),(0,0),(20*math.cos(math.radians(angle)),20*math.sin(math.radians(angle)))])
    assert m.CastleVertexPlan(m,r,2).kind=='corner'
    assert m.CastleVertexPlan(m,r,2).cut==(3 if angle==135 else 2)
m.WallTypeIdx=m.CastleWallBase+5
r=run([(0,0),(24,0)])
assert m.CastleVertexPlan(m,r,1).m.endswith('merc_castle_tower_hand.cgf')
assert m.CastleVertexActive(m)
assert m.CastleCornerFor(m,90,m.WallTypes[m.WallTypeIdx]) is None
m.CastleTowersOn=False
assert m.CastleVertexPlan(m,r,1) is None
for name in ['castle_tower','castle_tower_hand']:
    lua.execute((ROOT/('data/Scripts/mods/prefabs/wall_'+name+'_decor.lua')).read_text())
    assert len(m.WallDecor[name])==4
m.CastleTowersOn=True
pl=m.CastleVertexPlan(m,r,1)
assert pl.decor=='castle_tower_hand' and pl.decorCount==4
lua.execute('''
System.SpawnEntity=function() return {id=123} end
mercenaries.WallSegEnts={}
mercenaries.testDecor={}
mercenaries.SpawnHousePart=function(self,model,pos,rx,ry,rz,scale,prefix,registry)
  table.insert(self.testDecor,{model=model,pos=pos})
  table.insert(registry,1000+#self.testDecor)
end
''')
m.CastleSpawnVertex(m,pl,r.pts[1])
assert len(m.testDecor)==4 and len(m.WallSegEnts)==5
result={'passed':True,'square_tower_orientations_checked':count,
        'additional_checks':['end towers','disabled towers','45/135-degree corner fallback','6m hand-wall tower selection','four decor props spawned and registered for cleanup'],
        'example_square':out}
dest=ROOT/'tmp/castle-rework/placement_checks.json';dest.parent.mkdir(parents=True,exist_ok=True)
dest.write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items() if k!='example_square'},indent=2))
