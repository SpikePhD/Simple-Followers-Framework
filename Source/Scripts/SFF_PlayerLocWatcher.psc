; ======================================================================
; SFF_PlayerLocationWatcher.psc — drive outfit auto-switch from location
; Attach to: ReferenceAlias "Player" on Quest "SFF_Outfits"
; ======================================================================

Scriptname SFF_PlayerLocationWatcher extends ReferenceAlias

Quest  Property SFF_OutfitsManagerQuest Auto
Bool   Property DebugAll = False Auto

; Location keywords (vanilla)
Keyword Property LocTypeCity         Auto
Keyword Property LocTypeTown         Auto
Keyword Property LocTypeSettlement   Auto
Keyword Property LocTypeHabitation   Auto
Keyword Property LocTypePlayerHouse  Auto

Event OnInit()
    EvaluateAndApply()
EndEvent

Event OnPlayerLoadGame()
    EvaluateAndApply()
EndEvent

Event OnLocationChange(Location akOldLoc, Location akNewLoc)
    EvaluateAndApply()
EndEvent

Function EvaluateAndApply()
    Actor p = GetReference() as Actor
    if p == None
        return
    endif

    String mode = "Adventure" ; default
    Location L = p.GetCurrentLocation()

    if L != None
        ; Home beats Town if explicitly a player house
        if LocTypePlayerHouse != None && L.HasKeyword(LocTypePlayerHouse)
            mode = "Home"
        else
            Bool inTown = False
            if LocTypeCity != None && L.HasKeyword(LocTypeCity)
                inTown = True
            elseif LocTypeTown != None && L.HasKeyword(LocTypeTown)
                inTown = True
            elseif LocTypeSettlement != None && L.HasKeyword(LocTypeSettlement)
                inTown = True
            elseif LocTypeHabitation != None && L.HasKeyword(LocTypeHabitation)
                inTown = True
            endif
            if inTown
                mode = "Town"
            endif
        endif
    endif

    if DebugAll
        Debug.Notification("[SFF] Location mode -> " + mode)
    endif

    SFF_OutfitsManager mgr = SFF_OutfitsManagerQuest as SFF_OutfitsManager
    if mgr != None
        mgr.ApplyModeForAll(mode)
    endif
EndFunction