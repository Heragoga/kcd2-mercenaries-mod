"""Export actual Lua placement plans for Blender mesh-level join validation."""
import json
import math
from pathlib import Path
from lupa.luajit21 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('mercenaries={DevCommand=function() end}; System={LogAlways=function() end}; Script={LoadScript=function() end}')
for name in ['wall','castle']:
    lua.execute((ROOT/('data/Scripts/mods/mercenaries_'+name+'.lua')).read_text(encoding='utf-8-sig'))
m=lua.globals().mercenaries
m.WallUp=0;m.WallLat=0;m.WallSnap=False;m.CastleTowerEvery=1
def plain(t):
    if hasattr(t,'items'):return {str(k):plain(v) for k,v in t.items()}
    return t
layouts=[]
for walltype in [1,5]:
    m.WallTypeIdx=m.CastleWallBase+walltype;m.WallSegLen=None
    wt=m.WallTypes[m.WallTypeIdx]
    cases=[('square',[(0,0),(40,0),(40,40),(0,40)],True,0),
           ('rotated_square',[(0,0),(40,0),(40,40),(0,40)],True,37),
           ('open_end',[(0,0),(40,0)],False,0),
           ('bend',[(-40,0),(0,0),(0,40)],False,0)]
    if walltype==1:
        for angle in [45,90,135]:
            cases.append(('corner'+str(angle),[(-30,0),(0,0),(30*math.cos(math.radians(angle)),30*math.sin(math.radians(angle)))],False,0))
    for title,pts,closed,angle in cases:
        m.CastleTowerEvery=0 if title.startswith('corner') else 1
        c,s=math.cos(math.radians(angle)),math.sin(math.radians(angle))
        points=[lua.table_from(dict(x=x*c-y*s,y=x*s+y*c,z=0)) for x,y in pts]
        run=lua.table_from(dict(pts=lua.table_from(points),closed=closed))
        plans=[m.CastleVertexPlan(m,run,i+1) for i in range(len(pts))]
        instances=[];vertices=[];edges=[]
        for i,p in enumerate(plans):
            if p is None:continue
            a=points[i]
            inst={'model':p.m,'pos':{'x':a.x+(p.dx or 0),'y':a.y+(p.dy or 0),'z':a.z+(p.up or 0)},'yaw':p.yaw}
            instances.append(inst);vertices.append({'index':i,'kind':p.kind,'instance':inst})
        for i in range(len(pts) if closed else len(pts)-1):
            j=(i+1)%len(pts)
            ca=plans[i].cut if plans[i] is not None else 0
            cb=plans[j].cut if plans[j] is not None else 0
            segments=m.WallEdgeSegments(m,points[i],points[j],True,ca,cb)
            edge={'from':i,'to':j,'start':plain(points[i]),'end':plain(points[j]),'cutA':ca,'cutB':cb,'segments':[]}
            for k in range(1,len(segments)+1):
                model=wt.vary[(k-1)%len(wt.vary)+1] if wt.vary else wt.m
                inst={'model':model,'pos':plain(segments[k].pos),'yaw':segments[k].yaw}
                instances.append(inst);edge['segments'].append(inst)
            edges.append(edge)
        layouts.append({'name':str(walltype)+'_'+title,'walltype':walltype,'walkheight':wt.walkheight,
                        'walkcenter':wt.walkcenter,'segment_length':wt.len,'instances':instances,'vertices':vertices,'edges':edges})
dest=ROOT/'tmp/castle-rework/layouts.json';dest.write_text(json.dumps(layouts,indent=2))
print('Exported',len(layouts),'real Lua layouts to',dest)
