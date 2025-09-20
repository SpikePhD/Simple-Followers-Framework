Scriptname SFF_Log Hidden

; =========
; Simple, SKSE-aware logger for SFF
; - Writes to dedicated SKSE user log: "SKSE\SFF.log"
; - Also mirrors important lines to Papyrus.0.log (Trace/TraceStack)
; =========

; --- Internal: always make sure user log is open ---
Function OpenUserLog() global
    ; Safe to call repeatedly; SKSE ignores duplicate opens.
    Debug.OpenUserLog("SFF")
EndFunction

; --- Basic levels ---
Function Info(string msg) global
    OpenUserLog()
    Debug.TraceUser("SFF", "[INFO] " + msg)
EndFunction

Function Warn(string msg) global
    OpenUserLog()
    Debug.TraceUser("SFF", "[WARN] " + msg)
    Debug.Trace("[SFF][WARN] " + msg) ; mirror to Papyrus.0.log
EndFunction

Function Error(string msg) global
    OpenUserLog()
    Debug.TraceUser("SFF", "[ERROR] " + msg)
    Debug.Trace("[SFF][ERROR] " + msg) ; mirror to Papyrus.0.log
    Debug.TraceStack("[SFF][STACK] " + msg) ; include call stack in Papyrus.0.log
EndFunction

; --- Convenience: dump an actor’s identity safely ---
Function DumpActor(Actor a) global
    if !a
        Info("Actor = None")
        return
    endif

    string nm = a.GetDisplayName()
    if nm == ""
        nm = "Follower"
    endif

    int fid = a.GetFormID()
    Form base = a.GetBaseObject()
    int bid = 0
    if base
        bid = base.GetFormID()
    endif

    ; Papyrus can't format hex; ints show in decimal in logs. That's fine for search.
    Info("Actor dump => Name='" + nm + "' RefFormID=" + fid + " BaseFormID=" + bid)
EndFunction