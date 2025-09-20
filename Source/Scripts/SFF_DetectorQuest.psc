; SFF_DetectorQuest.psc  (force-refresh version)
Scriptname SFF_DetectorQuest extends Quest

Spell Property SFF_FollowerSenseAbility Auto

Event OnInit()
    RefreshAbility()
EndEvent

Event OnPlayerLoadGame()
    ; nudge once after load
    RegisterForSingleUpdate(0.5)
EndEvent

Event OnUpdate()
    RefreshAbility()
EndEvent

Function RefreshAbility()
    Actor p = Game.GetPlayer()
    if p && SFF_FollowerSenseAbility
        ; hard refresh to guarantee the cloak is running with latest data
        if p.HasSpell(SFF_FollowerSenseAbility)
            p.DispelSpell(SFF_FollowerSenseAbility)
            Utility.Wait(0.1)
            p.RemoveSpell(SFF_FollowerSenseAbility)
        endif
        p.AddSpell(SFF_FollowerSenseAbility, false)
    endif
EndFunction