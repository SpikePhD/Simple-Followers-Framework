; SFF_State.psc — compile-safe with meta.partyCount + meta.lastUpdated

Scriptname SFF_State extends Quest
import StorageUtil

Int    Property MaxSlots = 4 Auto
String Property JsonDir = "SFF/Saves/" Auto
String Property JsonPrefix = "SFF_State_" Auto
String Property StorageNamespace = "SFF" Auto
Float  Property SaveDebounceSeconds = 0.5 Auto

Int[]    PartyFormIDs
String[] PartyNames
Float    _nextSaveAllowed = 0.0

String _jsonFile
Int    _charGuid

Event OnInit()
    InitArrays()
    EnsureCharGuid()
    _jsonFile = BuildJsonFile()
    RegisterForModEvent("SFF_Hired", "OnSFFHired")
    RegisterForModEvent("SFF_Dismissed", "OnSFFDismissed")
    LoadFromJsonIfPresent()
    Debug.Trace("[SFF] State init -> " + _jsonFile)
EndEvent

Event OnPlayerLoadGame()
    EnsureCharGuid()
    _jsonFile = BuildJsonFile()
    LoadFromJsonIfPresent()
EndEvent

Event OnSFFHired(Form akActorForm, Int akFormID, String akName)
    Int slot = FindSlotByForm(akFormID)
    if slot < 0
        slot = FindFreeSlot()
    endif
    if slot >= 0
        PartyFormIDs[slot] = akFormID
        PartyNames[slot]   = akName
    else
        Debug.Notification("[SFF] Party full (4). Not adding " + akName)
    endif
    AddToHistory(akFormID, akName)
    DebouncedSave()
EndEvent

Event OnSFFDismissed(Form akActorForm, Int akFormID, String akName)
    Int slot = FindSlotByForm(akFormID)
    if slot >= 0
        PartyFormIDs[slot] = 0
        PartyNames[slot]   = ""
    endif
    AddToHistory(akFormID, akName)
    DebouncedSave()
EndEvent

Function InitArrays()
    PartyFormIDs = new Int[4]
    PartyNames   = new String[4]
    Int i = 0
    while i < 4
        PartyFormIDs[i] = 0
        PartyNames[i]   = ""
        i += 1
    endwhile
EndFunction

Int Function FindSlotByForm(Int fid)
    if fid <= 0
        return -1
    endif
    Int i = 0
    while i < 4
        if PartyFormIDs[i] == fid
            return i
        endif
        i += 1
    endwhile
    return -1
EndFunction

Int Function FindFreeSlot()
    Int i = 0
    while i < 4
        if PartyFormIDs[i] == 0
            return i
        endif
        i += 1
    endwhile
    return -1
EndFunction

Int Function CountNonZero(Int[] arr)
    Int c = 0
    Int i = 0
    while i < 4
        if arr[i] != 0
            c += 1
        endif
        i += 1
    endwhile
    return c
EndFunction

Function AddToHistory(Int fid, String nm)
    if fid <= 0
        return
    endif

    String keyStr   = (fid as String)
    String pathName = "history." + keyStr + ".name"
    String pathFirst= "history." + keyStr + ".firstSeen"

    String existingName = JsonUtil.GetStringValue(_jsonFile, pathName, "")
    Int    firstSeen    = JsonUtil.GetIntValue(_jsonFile, pathFirst, 0)

    if firstSeen == 0
        ; first time we see this follower (keep the map)
        JsonUtil.SetStringValue(_jsonFile, pathName, nm)
        JsonUtil.SetIntValue(_jsonFile, pathFirst, (Utility.GetCurrentRealTime() as Int))

        ; >>> NEW: also append to a simple array for MCM listing <<<
        Int count = JsonUtil.GetIntValue(_jsonFile, "meta.historyCount", 0)
        String base = "history[" + (count as String) + "]"
        JsonUtil.SetIntValue(  _jsonFile, base + ".formID", fid)
        JsonUtil.SetStringValue(_jsonFile, base + ".name",   nm)
        JsonUtil.SetIntValue(  _jsonFile, "meta.historyCount", count + 1)
        ; <<< END NEW
    else
        if nm != ""
            JsonUtil.SetStringValue(_jsonFile, pathName, nm)
        endif
    endif
EndFunction

Function DebouncedSave()
    Float now = Utility.GetCurrentRealTime()
    if now < _nextSaveAllowed
        return
    endif
    _nextSaveAllowed = now + SaveDebounceSeconds
    SaveJson()
EndFunction

Actor Function GetHistoryActor(Int idx)
    ; If unknown, return None (Actor can be None safely).
    ; But do not ever return None for String/Int functions.
    ; Your existing implementation is fine here.
EndFunction

String Function SFF_GetJsonPath()
    Actor p = Game.GetPlayer()
    if p == None
        return ""
    endif
    Int g = StorageUtil.GetIntValue(p, "SFF_CharGuid") ; same namespace MCM uses
    if g <= 0
        return ""
    endif
    return "SFF/Saves/SFF_State_" + ("" + g) + ".json"
EndFunction

Int Function GetHistoryCount()
    String jf = SFF_GetJsonPath()
    if jf == ""
        return 0
    endif
    ; Direct read with a default; no PathExists needed
    Int n = JsonUtil.GetIntValue(jf, "meta.historycount", 0)
    if n < 0
        n = 0
    endif
    return n
EndFunction

String Function GetHistoryName(Int idx)
    if idx < 0
        return ""
    endif
    String jf = SFF_GetJsonPath()
    if jf == ""
        return ""
    endif
    String s = JsonUtil.GetStringValue(jf, "history[" + ("" + idx) + "].name", "")
    ; Only check for empty string (never compare to None)
    if s == ""
        return ""
    endif
    return s
EndFunction
Function SaveJson()
    ; meta
    JsonUtil.SetIntValue(_jsonFile, "meta.charGuid", _charGuid)
    JsonUtil.SetIntValue(_jsonFile, "meta.partyCount", CountNonZero(PartyFormIDs))
    JsonUtil.SetIntValue(_jsonFile, "meta.lastUpdated", (Utility.GetCurrentRealTime() as Int))

    ; party[0..3]
    Int i = 0
    while i < 4
        String idx = (i as String)
        String base = "party[" + idx + "]"
        JsonUtil.SetIntValue(_jsonFile, base + ".formID", PartyFormIDs[i])
        JsonUtil.SetStringValue(_jsonFile, base + ".name",   PartyNames[i])
        i += 1
    endwhile

    JsonUtil.Save(_jsonFile)

    int h = ModEvent.Create("SFF_StateChanged")
    if h
        ModEvent.Send(h)
    endif

    Debug.Trace("[SFF] State saved -> " + _jsonFile)
EndFunction

Function LoadFromJsonIfPresent()
    Int i = 0
    while i < 4
        String idx = (i as String)
        String base = "party[" + idx + "]"
        PartyFormIDs[i] = JsonUtil.GetIntValue(_jsonFile, base + ".formID", 0)
        PartyNames[i]   = JsonUtil.GetStringValue(_jsonFile, base + ".name", "")
        i += 1
    endwhile
    _charGuid = JsonUtil.GetIntValue(_jsonFile, "meta.charGuid", _charGuid)
    Debug.Trace("[SFF] State loaded <- " + _jsonFile)
EndFunction

Function EnsureCharGuid()
    Actor p = Game.GetPlayer()
    if p == None
        return
    endif
    Int g = StorageUtil.GetIntValue(p, StorageNamespace + "_CharGuid")
    if g <= 0
        g = Utility.RandomInt(100000, 2147483647)
        StorageUtil.SetIntValue(p, StorageNamespace + "_CharGuid", g)
    endif
    _charGuid = g
EndFunction

String Function BuildJsonFile()
    return JsonDir + JsonPrefix + (_charGuid as String) + ".json"
EndFunction

Actor Function GetPartyActor(Int slotIdx)
    if slotIdx < 0 || slotIdx >= 4
        return None
    endif
    Int fid = PartyFormIDs[slotIdx]
    if fid <= 0
        return None
    endif
    Form f = Game.GetFormEx(fid)
    if f == None
        ; try base file fallback if needed, or skip
        return None
    endif
    return f as Actor
EndFunction
