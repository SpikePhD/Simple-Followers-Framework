; ======================================================================
; SFF_OutfitsManager.psc
; Purpose:
;   - Save currently equipped Armor/Clothing/Jewelry on a follower into named sets
;   - Apply a saved set on demand (from MCM or auto-switch)
;   - Auto-switch sets based on location class (Adventure/Town/Home)
; Attach to:
;   Quest "SFF_Outfits" (Start Game Enabled = ON, Run Once = OFF)
; Requirements:
;   - SKSE64
;   - PapyrusUtil (JsonUtil, StorageUtil)
; Notes:
;   - No ternary. No variable-sized arrays. Fixed sizes only.
; ======================================================================

Scriptname SFF_OutfitsManager extends Quest
import StorageUtil
import JsonUtil

; ---------- Properties ----------
Actor  Property PlayerRef Auto
Bool   Property DebugAll = False Auto

String Property JsonDir = "SFF/Saves/" Auto
String Property JsonPrefix = "SFF_Outfits_" Auto
String Property StorageNamespace = "SFF" Auto

; Outfit set names (JSON keys)
String Property KEY_TEMP      = "temp" Auto
String Property KEY_ADVENTURE = "adventure" Auto
String Property KEY_TOWN      = "town" Auto
String Property KEY_HOME      = "home" Auto

; ---------- Runtime ----------
String _jsonFile = ""

; ======================================================================
; Lifecycle
; ======================================================================
Event OnInit()
    if PlayerRef == None
        PlayerRef = Game.GetPlayer()
    endif
    EnsureJsonPath()
    RegisterForModEvent("SFF_OutfitCommand", "OnOutfitCommand")
    RegisterForModEvent("SFF_LocationClassChanged", "OnLocationClassChanged")
    if DebugAll
        Debug.Trace("[SFF] Outfits manager ready. json=" + _jsonFile)
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

; ======================================================================
; MCM -> ModEvent handler
; SendModEvent("SFF_OutfitCommand", "<cmd>", slotIndexFloat)
; ======================================================================
Event OnOutfitCommand(String eventName, String cmd, float numArg, Form sender)
    ; ---- declare locals first ----
    Int    slotIdx = numArg as Int
    Actor  a = GetFollowerBySlot(slotIdx)

    if a == None
        Debug.Notification("[SFF] Outfit: no actor in slot " + ("" + slotIdx))
        return
    endif

    ; -------- main commands --------
    if cmd == "Save"
        SaveCurrentOutfit(a, KEY_TEMP)
        Debug.Notification("[SFF] Saved current outfit (Temp) for " + SafeName(a))
        return
    ElseIf cmd == "Load"
        ApplyOutfitSet(a, KEY_TEMP)
        return
    ElseIf cmd == "SetAdventure"
        SaveCurrentOutfit(a, KEY_ADVENTURE)
        Debug.Notification("[SFF] Set Adventure outfit for " + SafeName(a))
        return
    ElseIf cmd == "SetTown"
        SaveCurrentOutfit(a, KEY_TOWN)
        Debug.Notification("[SFF] Set Town outfit for " + SafeName(a))
        return
    ElseIf cmd == "SetHome"
        SaveCurrentOutfit(a, KEY_HOME)
        Debug.Notification("[SFF] Set Home outfit for " + SafeName(a))
        return
    EndIf

    ; -------- explicit remove buttons --------
    if cmd == "RemoveAdventure"
        RemoveSetForActor(a, KEY_ADVENTURE)
        return
    ElseIf cmd == "RemoveTown"
        RemoveSetForActor(a, KEY_TOWN)
        return
    ElseIf cmd == "RemoveHome"
        RemoveSetForActor(a, KEY_HOME)
        return
    EndIf

    ; -------- text "remove:<tag>" parsing --------
    if cmd != ""
        if cmd == "remove:" + KEY_ADVENTURE
            RemoveSetForActor(a, KEY_ADVENTURE)
            return
        ElseIf cmd == "remove:" + KEY_TOWN
            RemoveSetForActor(a, KEY_TOWN)
            return
        ElseIf cmd == "remove:" + KEY_HOME
            RemoveSetForActor(a, KEY_HOME)
            return
        endif
    endif
EndEvent

; Optional event (if you broadcast mode via ModEvent)
Event OnLocationClassChanged(String eventName, String modeStr, float numArg, Form sender)
    ApplyModeForAll(modeStr)
EndEvent

; ======================================================================
; Public entry for a Player alias watcher (no ModEvent required)
; mode = "Home" / "Town" / "Adventure"
; ======================================================================
Function ApplyModeForAll(String mode)
    EnsureJsonPath()
    Int i = 0
    while i < 4
        Actor a = GetFollowerBySlot(i)
        if a != None
            if mode == "Home"
                if GetSetCountForActor(a, KEY_HOME) > 0
                    ApplyOutfitToActor(a, GetSetForSlot(i, KEY_HOME), 64, True, DebugAll)
                endif
            ElseIf mode == "Town"
                if GetSetCountForActor(a, KEY_TOWN) > 0
                    ApplyOutfitToActor(a, GetSetForSlot(i, KEY_TOWN), 64, True, DebugAll)
                endif
            else
                if GetSetCountForActor(a, KEY_ADVENTURE) > 0
                    ApplyOutfitToActor(a, GetSetForSlot(i, KEY_ADVENTURE), 64, False, DebugAll)
                endif
            endif
        endif
        i += 1
    endwhile
EndFunction

; ======================================================================
; Save currently worn items -> JSON
; followers[<fid>].sets.<name>.*  (formid + plugin)
; ======================================================================
Function SaveCurrentOutfit(Actor a, String setName)
    if a == None
        return
    endif
    Int fid = a.GetFormID()
    String base = "followers[" + ("" + fid) + "].sets." + setName

    JsonUtil.ClearPath(_jsonFile, base)

    Int count = 0
    Int invCount = a.GetNumItems()
    Int k = 0
    while k < invCount
        Form it = a.GetNthForm(k)
        if it != None
            Armor ar = it as Armor
            if ar != None
                if a.IsEquipped(ar)
                    String entry = base + ".items[" + ("" + count) + "]"
                    JsonUtil.SetIntValue(_jsonFile, entry + ".formid", ar.GetFormID())
                    JsonUtil.SetStringValue(_jsonFile, entry + ".plugin", GetPluginFor(ar))
                    count += 1
                    if count >= 64
                        k = invCount ; break
                    endif
                endif
            endif
        endif
        k += 1
    endwhile

    JsonUtil.SetIntValue(_jsonFile, base + ".count", count)
    JsonUtil.Save(_jsonFile)

    if DebugAll
        Debug.Trace("[SFF] Saved outfit (" + setName + ") for " + SafeName(a) + " count=" + ("" + count))
    endif
EndFunction

; ======================================================================
; Load & apply a named set
; ======================================================================
Function ApplyOutfitSet(Actor a, String setName)
    if a == None
        return
    endif
    Int fid = a.GetFormID()
    String base = "followers[" + ("" + fid) + "].sets." + setName
    Int n = JsonUtil.GetIntValue(_jsonFile, base + ".count", 0)
    if n <= 0
        if DebugAll
            Debug.Trace("[SFF] No outfit saved for " + SafeName(a) + " set=" + setName)
        endif
        return
    endif

    Form[] items = new Form[64]
    Int kept = 0
    Int i = 0
    while i < n && i < 64
        String entry = base + ".items[" + ("" + i) + "]"
        Int    itemID = JsonUtil.GetIntValue(_jsonFile, entry + ".formid", 0)
        String plugin = JsonUtil.GetStringValue(_jsonFile, entry + ".plugin", "Skyrim.esm")

        if itemID > 0
            Form f = Game.GetFormEx(itemID)
            if f == None
                if plugin != ""
                    f = Game.GetFormFromFile(itemID, plugin)
                endif
            endif
            if f != None
                items[kept] = f
                kept += 1
            endif
        endif
        i += 1
    endwhile

    ApplyOutfitToActor(a, items, kept, False, DebugAll)

    if DebugAll
        Debug.Trace("[SFF] Applied outfit (" + setName + ") to " + SafeName(a))
    endif
EndFunction

; ======================================================================
; Outfit application helpers
; ======================================================================
Bool Function IsClothing(Form f)
    Armor ar = f as Armor
    if ar != None
        if ar.GetArmorRating() <= 0.0
            return True
        endif
    endif
    return False
EndFunction

Int Function NormalizeSet(Form[] src, Form[] dst, Bool clothingOnly)
    Int n = 0
    Int i = 0
    while i < src.Length
        Form f = src[i]
        if f != None
            Bool ok = True
            if clothingOnly
                ok = IsClothing(f)
            endif
            if ok
                Int j = 0
                Bool exists = False
                while j < n
                    if dst[j] == f
                        exists = True
                        j = n
                    endif
                    j += 1
                endwhile
                if !exists
                    dst[n] = f
                    n += 1
                    if n >= dst.Length
                        i = src.Length
                    endif
                endif
            endif
        endif
        i += 1
    endwhile
    return n
EndFunction

Function ApplyOutfitToActor(Actor a, Form[] items, Int itemsCount, Bool preferClothing, Bool debugAll)
    if a == None
        return
    endif

    Form[] filtered = new Form[64]
    Int kept = NormalizeSet(items, filtered, preferClothing)
    if kept > 64
        kept = 64
    endif

    Weapon rh = a.GetEquippedWeapon(False)
    if rh != None
        if a.IsEquipped(rh)
            a.UnequipItem(rh, True, True)
        endif
    endif

    Weapon lh = a.GetEquippedWeapon(True)
    if lh != None
        if a.IsEquipped(lh)
            a.UnequipItem(lh, True, True)
        endif
    endif

    Armor sh = a.GetEquippedShield()
    if sh != None
        if a.IsEquipped(sh)
            a.UnequipItem(sh, True, True)
        endif
    endif

    Int invCount = a.GetNumItems()
    Int k = 0
    while k < invCount
        Form it = a.GetNthForm(k)
        Armor ar = it as Armor
        if ar != None
            Bool keep = False
            Int m = 0
            while m < kept
                if filtered[m] == it
                    keep = True
                    m = kept
                endif
                m += 1
            endwhile

            if !keep
                if a.IsEquipped(ar)
                    a.UnequipItem(ar, True, True)
                endif
            endif
        endif
        k += 1
    endwhile

    Utility.Wait(0.1)

    Int e = 0
    while e < kept
        Armor equipAr = filtered[e] as Armor
        if equipAr != None
            a.EquipItem(equipAr, True, True)
        endif
        e += 1
    endwhile

    if debugAll
        String modeText = "Adventure"
        if preferClothing
            modeText = "Town/Home"
        endif
        Debug.Notification("[SFF] Applied outfit (" + modeText + ") to " + a.GetLeveledActorBase().GetName())
    endif
EndFunction

Int Function GetSetCountForActor(Actor a, String tag)
    if a == None
        return 0
    endif
    EnsureJsonPath()
    Int fid = a.GetFormID()
    if fid <= 0
        return 0
    endif
    String base = "followers[" + ("" + fid) + "].sets." + tag
    return JsonUtil.GetIntValue(_jsonFile, base + ".count", 0)
EndFunction

; ======================================================================
; Data access helpers
; ======================================================================
Form[] Function GetSetForSlot(Int idx, String tag)
    EnsureJsonPath()

    Int fid = 0
    String nm = ""

    String pbase = "party[" + ("" + idx) + "]"
    fid = JsonUtil.GetIntValue(  "SFF/Saves/" + "SFF_State_" + GetCharGuidString() + ".json", pbase + ".formID", 0)
    nm  = JsonUtil.GetStringValue("SFF/Saves/" + "SFF_State_" + GetCharGuidString() + ".json", pbase + ".name", "")

    if fid <= 0 && nm == ""
        Form[] empty0 = new Form[64]
        return empty0
    endif

    String root = "followers[" + ("" + fid) + "].sets." + tag
    Int count   = JsonUtil.GetIntValue(_jsonFile, root + ".count", 0)
    if count <= 0
        Form[] empty1 = new Form[64]
        return empty1
    endif

    Form[] out = new Form[64]
    Int kept = 0
    Int i = 0
    while i < count && i < 64
        String pForm = root + ".items[" + ("" + i) + "].formid"
        String pPlug = root + ".items[" + ("" + i) + "].plugin"
        Int    id    = JsonUtil.GetIntValue(_jsonFile, pForm, 0)
        String plg   = JsonUtil.GetStringValue(_jsonFile, pPlug, "")
        if id > 0
            Form f = Game.GetFormEx(id)
            if f == None
                if plg != ""
                    f = Game.GetFormFromFile(id, plg)
                endif
            endif
            if f != None
                out[kept] = f
                kept += 1
                if kept >= 64
                    i = count
                endif
            endif
        endif
        i += 1
    endwhile
    return out
EndFunction

Actor Function GetFollowerBySlot(Int idx)
    EnsureJsonPath()

    String pbase = "party[" + ("" + idx) + "]"
    String stateJson = "SFF/Saves/" + "SFF_State_" + GetCharGuidString() + ".json"

    Int fid = JsonUtil.GetIntValue(stateJson, pbase + ".formID", 0)
    String nm = JsonUtil.GetStringValue(stateJson, pbase + ".name", "")

    if fid <= 0 && nm == ""
        return None
    endif
    return ResolveActor(fid, nm)
EndFunction

String Function GetCharGuidString()
    Actor p = Game.GetPlayer()
    if p == None
        return "0"
    endif
    Int g = StorageUtil.GetIntValue(p, StorageNamespace + "_CharGuid")
    if g <= 0
        g = 0
    endif
    return ("" + g)
EndFunction

; ---------- Resolver ----------
Actor Function ResolveActor(Int fid, String nm)
    Actor a = None

    if fid > 0
        Form f = Game.GetFormEx(fid)
        if f != None
            a = f as Actor
            if a != None
                return a
            endif

            ActorBase ab0 = f as ActorBase
            if ab0 != None
                a = FindLoadedActorByBase(ab0)
                if a != None
                    return a
                endif
            endif
        endif

        Form fSk = Game.GetFormFromFile(fid, "Skyrim.esm")
        if fSk != None
            a = fSk as Actor
            if a != None
                return a
            endif
            ActorBase ab = fSk as ActorBase
            if ab != None
                a = FindLoadedActorByBase(ab)
                if a != None
                    return a
                endif
            endif
        endif
    endif

    if nm != ""
        a = FindLoadedActorByName(nm)
        if a != None
            return a
        endif
    endif

    return None
EndFunction

Actor Function FindLoadedActorByBase(ActorBase ab)
    if ab == None
        return None
    endif
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
            ActorBase cb = cand.GetLeveledActorBase()
            if cb == ab
                return cand
            endif
        endif
        i += 1
    endwhile
    return None
EndFunction

Actor Function FindLoadedActorByName(String nm)
    if nm == ""
        return None
    endif
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
            if disp != ""
                if disp == nm
                    return cand
                endif
            endif
        endif
        i += 1
    endwhile
    return None
EndFunction

; Simple helper  default to Skyrim.esm; expand if you need plugin detection.
String Function GetPluginFor(Form f)
    return "Skyrim.esm"
EndFunction

; Display-safe name
String Function SafeName(Actor a)
    if a == None
        return "(None)"
    endif
    ActorBase ab = a.GetLeveledActorBase()
    if ab != None
        String n = ab.GetName()
        if n != ""
            return n
        endif
    endif
    return "(Actor)"
EndFunction

Function RemoveSetForActor(Actor a, String setName)
    if a == None
        return
    endif

    EnsureJsonPath()

    Int fid = a.GetFormID()
    if fid <= 0
        return
    endif

    String base = "followers[" + ("" + fid) + "].sets." + setName
    Int n = JsonUtil.GetIntValue(_jsonFile, base + ".count", 0)
    if n <= 0
        Debug.Notification("[SFF] No saved " + setName + " outfit for " + SafeName(a) + ".")
        return
    endif

    UnequipSetFromActor_JSON(a, base, n)

    JsonUtil.ClearPath(_jsonFile, base)
    JsonUtil.Save(_jsonFile)

    a.EvaluatePackage()

    Debug.Notification("[SFF] " + SafeName(a) + " will choose their own equipment for " + setName + ".")
    if DebugAll
        Debug.Trace("[SFF] Cleared outfit '" + setName + "' for fid=" + ("" + fid))
    endif
EndFunction

Function UnequipSetFromActor_JSON(Actor a, String base, Int count)
    Int i = 0
    while i < count && i < 64
        String entry = base + ".items[" + ("" + i) + "]"
        Int    id    = JsonUtil.GetIntValue(_jsonFile, entry + ".formid", 0)
        String plg   = JsonUtil.GetStringValue(_jsonFile, entry + ".plugin", "Skyrim.esm")
        if id > 0
            Form f = Game.GetFormEx(id)
            if f == None && plg != ""
                f = Game.GetFormFromFile(id, plg)
            endif
            Armor ar = f as Armor
            if ar != None
                a.UnequipItem(ar, True, True)
                if a.IsEquipped(ar)
                    a.RemoveItem(ar, 1, True, Game.GetPlayer())
                    Game.GetPlayer().RemoveItem(ar, 1, True, a)
                endif
            endif
        endif
        i += 1
    endwhile
EndFunction
