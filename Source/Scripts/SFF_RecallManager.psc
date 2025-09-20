; ======================================================================
; SFF_RecallManager.psc — recall a follower by History index
; Purpose: Resolve stored history entry (formID + name) to a live Actor and MoveTo the player.
; Attach to: Quest "SFF_RecallManager" (Start Game Enabled = ON, Run Once = OFF)
; Requires: SKSE (GetFormEx), PapyrusUtil (JsonUtil), SkyUI (MCM sends the event)
; ======================================================================

Scriptname SFF_RecallManager extends Quest
import JsonUtil
import StorageUtil

; -------- Properties (fill in CK) -------------------------------------
Quest   Property SFF_StateQuest Auto
Faction Property CurrentFollowerFaction Auto ; optional, not required for recall
Actor   Property PlayerRef Auto
Float   Property TeleportOffset = 150.0 Auto
Bool    Property DebugAll = False Auto

String Property JsonDir = "SFF/Saves/" Auto
String Property JsonPrefix = "SFF_State_" Auto
String Property StorageNamespace = "SFF" Auto

; -------- Runtime ------------------------------------------------------
String _jsonFile = ""

Event OnInit()
    if PlayerRef == None
        PlayerRef = Game.GetPlayer()
    endif
    EnsureJsonPath()
    RegisterForModEvent("SFF_RecallRequest", "OnRecallRequest")
    if DebugAll
        Debug.Trace("[SFF] RecallManager ready, json=" + _jsonFile)
    endif
EndEvent

Function EnsureJsonPath()
    if _jsonFile != ""
        return
    endif
    Actor p = Game.GetPlayer()
    if p == None
        return
    endif
    Int g = StorageUtil.GetIntValue(p, StorageNamespace + "_CharGuid")
    if g <= 0
        g = Utility.RandomInt(100000, 2147483647)
        StorageUtil.SetIntValue(p, StorageNamespace + "_CharGuid", g)
    endif
    _jsonFile = JsonDir + JsonPrefix + ("" + g) + ".json"
EndFunction

; -------------------- ModEvent from MCM -------------------------------

Event OnRecallRequest(string eventName, string strArg, float idxF, Form sender)
    Int idx = idxF as Int
    EnsureJsonPath()

    String pathBase = "history[" + ("" + idx) + "]"
    String nm = JsonUtil.GetStringValue(_jsonFile, pathBase + ".name", "")
    Int    fid = JsonUtil.GetIntValue(  _jsonFile, pathBase + ".formID", 0)

    if DebugAll
        String nmLog = nm
        if nmLog == ""
            nmLog = "(empty)"
        endif
        Debug.Trace("[SFF] Recall request idx=" + ("" + idx) + " name=" + nmLog + " fid=" + ("" + fid))
    endif

    Actor target = ResolveActor(fid, nm)

    if target != None
        ; slight Z offset to avoid clipping into the player
        target.MoveTo(PlayerRef, 0.0, 0.0, TeleportOffset)
        if DebugAll
            Debug.Notification("[SFF] Recalled " + target.GetLeveledActorBase().GetName())
        endif
    else
        if nm == ""
            Debug.Notification("(SFF) Cannot resolve follower")
        else
            Debug.Notification("(SFF) Cannot resolve " + nm)
        endif
        if DebugAll
            Debug.Trace("[SFF] Resolve failed: fid=" + ("" + fid) + " name=" + nm)
        endif
    endif
EndEvent

; -------------------- Resolution helpers ------------------------------

Actor Function ResolveActor(Int fid, String nm)
    Actor a = None

    ; 1) Try SKSE full FormID (if later you store full ids)
    if fid > 0
        Form f = Game.GetFormEx(fid)
        if f != None
            a = f as Actor
            if a != None
                return a
            endif
        endif

        ; 2) Try Skyrim.esm with the SAME integer (your JSON has 78993 for Sven’s base 00013491)
        Form fSk = Game.GetFormFromFile(fid, "Skyrim.esm")
        if fSk != None
            a = fSk as Actor
            if a != None
                return a
            endif
            ActorBase ab = fSk as ActorBase
            if ab != None
                ObjectReference near = Game.FindClosestReferenceOfTypeFromRef(ab, PlayerRef, 100000.0)
                if near != None
                    a = near as Actor
                    if a != None
                        return a
                    endif
                endif
            endif
        endif

        ; 3) Optional: Update.esm fallback (safe no-op if not present)
        if a == None
            Form fUp = Game.GetFormFromFile(fid, "Update.esm")
            if fUp != None
                a = fUp as Actor
                if a != None
                    return a
                endif
                ActorBase upab = fUp as ActorBase
                if upab != None
                    ObjectReference upref = Game.FindClosestReferenceOfTypeFromRef(upab, PlayerRef, 100000.0)
                    if upref != None
                        a = upref as Actor
                        if a != None
                            return a
                        endif
                    endif
                endif
            endif
        endif
    endif

    ; 4) Soft fallback: scan currently loaded refs by display name (last resort, loaded area only)
    if nm != ""
        a = FindLoadedActorByName(nm)
        if a != None
            return a
        endif
    endif

    return None
EndFunction

Actor Function FindLoadedActorByName(String nm)
    Actor p = Game.GetPlayer()
    if p == None
        return None
    endif
    Cell c = p.GetParentCell()
    if c == None
        return None
    endif

    Int i = 0
    Int n = c.GetNumRefs(43) ; 43 = Actor
    while i < n
        ObjectReference r = c.GetNthRef(43, i)
        Actor cand = r as Actor
        if cand != None
            String disp = cand.GetLeveledActorBase().GetName()
            if disp != "" && disp == nm
                return cand
            endif
        endif
        i += 1
    endwhile

    return None
EndFunction