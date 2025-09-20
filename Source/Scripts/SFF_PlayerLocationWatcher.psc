; ======================================================================
; SFF_PlayerLocationWatcher.psc — decide Home/Town/Adventure for player
; Purpose:
;   - Detect when the player moves between location classes and ask the
;     outfits manager to apply the proper set for all followers.
;   - No ModEvents. Direct call into SFF_OutfitsManager.ApplyModeForAll().
; Attach to:
;   ReferenceAlias "Player" on Quest "SFF_Outfits"
; Requirements:
;   Base game only (vanilla Location keywords)
; Fill in CK:
;   - LocTypeCity           -> Keyword LocTypeCity
;   - LocTypeTown           -> Keyword LocTypeTown
;   - LocTypePlayerHouse    -> Keyword LocTypePlayerHouse
;   - SFF_OutfitsManagerQuest -> your SFF_Outfits quest (with SFF_OutfitsManager script)
;   - CheckSeconds (2.0–5.0), DebugAll (optional)
; ======================================================================

Scriptname SFF_PlayerLocationWatcher extends ReferenceAlias

; ---- Vanilla keywords to classify locations ----
Keyword Property LocTypeCity        Auto
Keyword Property LocTypeTown        Auto
Keyword Property LocTypePlayerHouse Auto

; The quest that has the SFF_OutfitsManager script
Quest Property SFF_OutfitsManagerQuest Auto

; Polling cadence (seconds). Keep modest to avoid spam.
Float Property CheckSeconds = 3.0 Auto
Bool  Property DebugAll = False Auto

; Cache last decided mode to avoid redundant calls
String _lastMode = ""  ; "Home" / "Town" / "Adventure"

Event OnInit()
    ; We can get an early decision on game start
    RegisterForSingleUpdate(CheckSeconds)
EndEvent

Event OnPlayerLoadGame()
    ; Re-evaluate shortly after load
    RegisterForSingleUpdate(1.0)
EndEvent

; Also react immediately on Location changes when the engine fires it
Event OnLocationChange(Location akOldLoc, Location akNewLoc)
    String mode = ComputeMode()
    ApplyIfChanged(mode)
EndEvent

Event OnUpdate()
    String mode = ComputeMode()
    ApplyIfChanged(mode)
    RegisterForSingleUpdate(CheckSeconds)
EndEvent

Function ApplyIfChanged(String mode)
    if mode == ""
        return
    endif
    if mode != _lastMode
        _lastMode = mode
        if DebugAll
            Debug.Notification("[SFF] Player mode -> " + mode)
        endif
        CallManager(mode)
    endif
EndFunction

; Decide the current mode from keywords on the player's current location
String Function ComputeMode()
    Actor p = GetReference() as Actor
    if p == None
        p = Game.GetPlayer()
    endif
    if p == None
        return ""
    endif

    Location loc = p.GetCurrentLocation()

    ; Home — any player house keyword trumps other classes
    if loc != None && LocTypePlayerHouse != None
        if loc.HasKeyword(LocTypePlayerHouse)
            return "Home"
        endif
    endif

    ; Town — cities or towns (interior or exterior hubs)
    if loc != None
        if (LocTypeCity != None && loc.HasKeyword(LocTypeCity)) || (LocTypeTown != None && loc.HasKeyword(LocTypeTown))
            return "Town"
        endif
    endif

    ; Default
    return "Adventure"
EndFunction

; Direct call into the outfits manager—no ModEvents needed
Function CallManager(String mode)
    if SFF_OutfitsManagerQuest == None
        return
    endif
    SFF_OutfitsManager m = SFF_OutfitsManagerQuest as SFF_OutfitsManager
    if m != None
        m.ApplyModeForAll(mode)
    endif
EndFunction