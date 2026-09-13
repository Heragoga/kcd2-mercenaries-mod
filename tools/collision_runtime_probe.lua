-- Test-only loader, appended to the packed main script by collision_package_probe.py.
-- Never shipped in the source mod and never saves the game.
MercCollisionProbe = {}
function MercCollisionProbe:OnGameplayStarted()
    Script.SetTimer(15000, function()
        System.LogAlways('[CollisionProbe] starting isolated native spawn cases')
        mercenaries.LabRepeats = 1
        mercenaries.LabWalk = 25
        mercenaries.LabCasesPhys = {
            { n='control', build='prop' },
            { n='dynamic_prop', build='spec', spec={class='mercenaries_Prop',aiObstacle=true} },
            { n='dynamic_rigid', build='spec', spec={class='RigidBodyEx',aiObstacle=true,
                physics={bRigidBodyActive=false,bResting=1,bPhysicalize=true,Mass=10000,Density=-1,bPushableByPlayers=false}},
                cvars={wh_ai_ObstaclesAddToCollisionAvoidance=1,wh_ai_FindPathUseObstacles=1} },
            { n='clear_control', build='none' },
        }
        mercenaries.LabAutoQuit = false
        mercenaries.LabLocate = {list=mercenaries:LabCandidates(),idx=0,phase='probe',t=0,here='loaded save'}
        mercenaries:ChainArm('LabLocator',250)
    end)
end
UIAction.RegisterEventSystemListener(MercCollisionProbe, '', 'OnGameplayStarted', 'OnGameplayStarted')
System.LogAlways('[CollisionProbe] test loader installed')
