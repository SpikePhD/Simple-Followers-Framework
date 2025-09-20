; ======================================================================
; SFF_MCM.psc — SkyUI MCM for Simple Followers Framework (Part 2)
; ======================================================================

Scriptname SFF_MCM extends SKI_ConfigBase
import StorageUtil
import JsonUtil

; ------------------ Config --------------------------------------------
String Property ModTitle = "Simple Followers Framework" Auto
Int    _version = 2

String Property JsonDir = "SFF/Saves/" Auto
String Property JsonPrefix = "SFF_State_" Auto
String Property StorageNamespace = "SFF" Auto

Quest Property SFF_StateQuest Auto

; ------------------ Runtime -------------------------------------------
String _jsonFile = ""
Int    _charGuid = 0

String[] _partyNames
Int[]    _partyIDs

; History UI
Int[] historyBtnIds         ; fixed 128 buffer allocated once
Int   historyBtnCount       ; how many are in use this render
String _currentPage = ""

; IDs for Follower 1..4 pages
Int bSave1 ;... keep all your existing IDs ...
Int bLoad1
Int bAdv1
Int bTown1
Int bHome1
Int bRmAdv1
Int bRmTown1
Int bRmHome1

Int bSave2
Int bLoad2
Int bAdv2
Int bTown2
Int bHome2
Int bRmAdv2
Int bRmTown2
Int bRmHome2

Int bSave3
Int bLoad3
Int bAdv3
Int bTown3
Int bHome3
Int bRmAdv3
Int bRmTown3
Int bRmHome3

Int bSave4
Int bLoad4
Int bAdv4
Int bTown4
Int bHome4
Int bRmAdv4
Int bRmTown4
Int bRmHome4

; ======================================================================
; SkyUI lifecycle
; ======================================================================

Event OnConfigInit()
    RegisterForModEvent("SFF_StateChanged", "OnSFFStateChanged")
    ; allocate once; never assign historyBtnIds = None / new Int[0]
    historyBtnIds = new Int[128]
    historyBtnCount = 0
EndEvent

Event OnConfigOpen()
    EnsureJsonPath()
EndEvent

Event OnPageReset(String a_page)
    _currentPage = a_page
    EnsureJsonPath()
    RefreshPartyFromJson()

    If (a_page == "Overview")
        AddHeaderOption("Overview")
        AddTextOption("Slot 1", SafeName(_partyNames[0]))
        AddTextOption("Slot 2", SafeName(_partyNames[1]))
        AddTextOption("Slot 3", SafeName(_partyNames[2]))
        AddTextOption("Slot 4", SafeName(_partyNames[3]))
        historyBtnCount = 0

    ElseIf (a_page == "Follower 1")
        AddHeaderOption("Follower 1")
        AddTextOption("Name", SafeName(_partyNames[0]))
        AddTextOption("FormID", ("" + _partyIDs[0]))
        bSave1 = AddTextOption("Save outfit (snapshot current)", "Save")
        bLoad1 = AddTextOption("Load saved (Temp)", "Load")
        bAdv1  = AddTextOption("Set current as Adventure", "Set")
        bTown1 = AddTextOption("Set current as Town", "Set")
        bHome1 = AddTextOption("Set current as Home", "Set")
        bRmAdv1  = AddTextOption("Remove Adventure Outfit", "Clear")
        bRmTown1 = AddTextOption("Remove Town Outfit", "Clear")
        bRmHome1 = AddTextOption("Remove Home Outfit", "Clear")
        historyBtnCount = 0

    ElseIf (a_page == "Follower 2")
        AddHeaderOption("Follower 2")
        AddTextOption("Name", SafeName(_partyNames[1]))
        AddTextOption("FormID", ("" + _partyIDs[1]))
        bSave2 = AddTextOption("Save outfit (snapshot current)", "Save")
        bLoad2 = AddTextOption("Load saved (Temp)", "Load")
        bAdv2  = AddTextOption("Set current as Adventure", "Set")
        bTown2 = AddTextOption("Set current as Town", "Set")
        bHome2 = AddTextOption("Set current as Home", "Set")
        bRmAdv2  = AddTextOption("Remove Adventure Outfit", "Clear")
        bRmTown2 = AddTextOption("Remove Town Outfit", "Clear")
        bRmHome2 = AddTextOption("Remove Home Outfit", "Clear")
        historyBtnCount = 0

    ElseIf (a_page == "Follower 3")
        AddHeaderOption("Follower 3")
        AddTextOption("Name", SafeName(_partyNames[2]))
        AddTextOption("FormID", ("" + _partyIDs[2]))
        bSave3 = AddTextOption("Save outfit (snapshot current)", "Save")
        bLoad3 = AddTextOption("Load saved (Temp)", "Load")
        bAdv3  = AddTextOption("Set current as Adventure", "Set")
        bTown3 = AddTextOption("Set current as Town", "Set")
        bHome3 = AddTextOption("Set current as Home", "Set")
        bRmAdv3  = AddTextOption("Remove Adventure Outfit", "Clear")
        bRmTown3 = AddTextOption("Remove Town Outfit", "Clear")
        bRmHome3 = AddTextOption("Remove Home Outfit", "Clear")
        historyBtnCount = 0

    ElseIf (a_page == "Follower 4")
        AddHeaderOption("Follower 4")
        AddTextOption("Name", SafeName(_partyNames[3]))
        AddTextOption("FormID", ("" + _partyIDs[3]))
        bSave4 = AddTextOption("Save outfit (snapshot current)", "Save")
        bLoad4 = AddTextOption("Load saved (Temp)", "Load")
        bAdv4  = AddTextOption("Set current as Adventure", "Set")
        bTown4 = AddTextOption("Set current as Town", "Set")
        bHome4 = AddTextOption("Set current as Home", "Set")
        bRmAdv4  = AddTextOption("Remove Adventure Outfit", "Clear")
        bRmTown4 = AddTextOption("Remove Town Outfit", "Clear")
        bRmHome4 = AddTextOption("Remove Home Outfit", "Clear")
        historyBtnCount = 0

    ElseIf (a_page == "History")
        BuildHistoryPage()
    EndIf
EndEvent

String Function GetTitle()
    return ModTitle
EndFunction

Int Function GetVersion()
    return _version
EndFunction

String[] Function GetPages()
    String[] pages = new String[6]
    pages[0] = "Overview"
    pages[1] = "Follower 1"
    pages[2] = "Follower 2"
    pages[3] = "Follower 3"
    pages[4] = "Follower 4"
    pages[5] = "History"
    return pages
EndFunction

; ======================================================================
; Helpers
; ======================================================================

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
    _charGuid = g
    _jsonFile = JsonDir + JsonPrefix + ("" + _charGuid) + ".json"
EndFunction

Function RefreshPartyFromJson()
    _partyNames = new String[4]
    _partyIDs   = new Int[4]
    Int i = 0
    while i < 4
        String base = "party[" + ("" + i) + "]"
        _partyNames[i] = JsonUtil.GetStringValue(_jsonFile, base + ".name", "")
        _partyIDs[i]   = JsonUtil.GetIntValue(_jsonFile, base + ".formID", 0)
        i += 1
    endwhile
EndFunction

String Function SafeName(String nm)
    if nm == ""
        return "Empty"
    endif
    return nm
EndFunction

; ======================================================================
; History page (click name -> recall)
; ======================================================================

Function BuildHistoryPage()
    Int n = JsonUtil.GetIntValue(_jsonFile, "meta.historycount", 0)
    if n < 0
        n = 0
    endif
    if n > 128
        n = 128
    endif
    historyBtnCount = n

    AddHeaderOption("History (" + ("" + n) + ")")

    Int i = 0
    while i < n
        String nm = JsonUtil.GetStringValue(_jsonFile, "history[" + ("" + i) + "].name", "")
        if nm == ""
            SFF_State st = SFF_StateQuest as SFF_State
            if st != None
                String s2 = st.GetHistoryName(i)
                if s2 != ""
                    nm = s2
                endif
            endif
        endif
        if nm == ""
            nm = "(unknown)"
        endif
        historyBtnIds[i] = AddTextOption(nm, "Recall")
        i += 1
    endwhile
EndFunction

; ======================================================================
; Input handling
; ======================================================================

Event OnOptionSelect(Int option)
    ; --- History page rows ---
    if _currentPage == "History"
        Int i = 0
        while i < historyBtnCount
            if option == historyBtnIds[i]
                SendModEvent("SFF_RecallRequest", "", i)
                return
            endif
            i += 1
        endwhile
        return
    endif

    ; --- Follower 1 ---
    if option == bSave1
        SendModEvent("SFF_OutfitCommand", "Save", 0.0)
    ElseIf option == bLoad1
        SendModEvent("SFF_OutfitCommand", "Load", 0.0)
    ElseIf option == bAdv1
        SendModEvent("SFF_OutfitCommand", "SetAdventure", 0.0)
    ElseIf option == bTown1
        SendModEvent("SFF_OutfitCommand", "SetTown", 0.0)
    ElseIf option == bHome1
        SendModEvent("SFF_OutfitCommand", "SetHome", 0.0)
    ElseIf option == bRmAdv1
        SendModEvent("SFF_OutfitCommand", "RemoveAdventure", 0.0)
    ElseIf option == bRmTown1
        SendModEvent("SFF_OutfitCommand", "RemoveTown", 0.0)
    ElseIf option == bRmHome1
        SendModEvent("SFF_OutfitCommand", "RemoveHome", 0.0)
    endif

    ; --- Follower 2 ---
    if option == bSave2
        SendModEvent("SFF_OutfitCommand", "Save", 1.0)
    ElseIf option == bLoad2
        SendModEvent("SFF_OutfitCommand", "Load", 1.0)
    ElseIf option == bAdv2
        SendModEvent("SFF_OutfitCommand", "SetAdventure", 1.0)
    ElseIf option == bTown2
        SendModEvent("SFF_OutfitCommand", "SetTown", 1.0)
    ElseIf option == bHome2
        SendModEvent("SFF_OutfitCommand", "SetHome", 1.0)
    ElseIf option == bRmAdv2
        SendModEvent("SFF_OutfitCommand", "RemoveAdventure", 1.0)
    ElseIf option == bRmTown2
        SendModEvent("SFF_OutfitCommand", "RemoveTown", 1.0)
    ElseIf option == bRmHome2
        SendModEvent("SFF_OutfitCommand", "RemoveHome", 1.0)
    endif

    ; --- Follower 3 ---
    if option == bSave3
        SendModEvent("SFF_OutfitCommand", "Save", 2.0)
    ElseIf option == bLoad3
        SendModEvent("SFF_OutfitCommand", "Load", 2.0)
    ElseIf option == bAdv3
        SendModEvent("SFF_OutfitCommand", "SetAdventure", 2.0)
    ElseIf option == bTown3
        SendModEvent("SFF_OutfitCommand", "SetTown", 2.0)
    ElseIf option == bHome3
        SendModEvent("SFF_OutfitCommand", "SetHome", 2.0)
    ElseIf option == bRmAdv3
        SendModEvent("SFF_OutfitCommand", "RemoveAdventure", 2.0)
    ElseIf option == bRmTown3
        SendModEvent("SFF_OutfitCommand", "RemoveTown", 2.0)
    ElseIf option == bRmHome3
        SendModEvent("SFF_OutfitCommand", "RemoveHome", 2.0)
    endif

    ; --- Follower 4 ---
    if option == bSave4
        SendModEvent("SFF_OutfitCommand", "Save", 3.0)
    ElseIf option == bLoad4
        SendModEvent("SFF_OutfitCommand", "Load", 3.0)
    ElseIf option == bAdv4
        SendModEvent("SFF_OutfitCommand", "SetAdventure", 3.0)
    ElseIf option == bTown4
        SendModEvent("SFF_OutfitCommand", "SetTown", 3.0)
    ElseIf option == bHome4
        SendModEvent("SFF_OutfitCommand", "SetHome", 3.0)
    ElseIf option == bRmAdv4
        SendModEvent("SFF_OutfitCommand", "RemoveAdventure", 3.0)
    ElseIf option == bRmTown4
        SendModEvent("SFF_OutfitCommand", "RemoveTown", 3.0)
    ElseIf option == bRmHome4
        SendModEvent("SFF_OutfitCommand", "RemoveHome", 3.0)
    endif
EndEvent

; Fired after SFF_State writes JSON (hire/dismiss/etc.)
Event OnSFFStateChanged(String eventName, String strArg, float numArg, Form sender)
    ForcePageReset()
EndEvent