#Requires AutoHotkey v2.0
#SingleInstance Force

;----------------------------------------------------------------------
; PoE Flasks macro - AutoHotkey v2 port of JoelStanford/PoEAutoFlask
;
; Keys used and monitored:
;   Alt+F12          - toggle automatic flask usage on/off
;   Right mouse btn  - primary attack skill (tracked, not swallowed)
;   1-5              - manually use a specific flask (timer still tracked)
;   ` (backtick)     - use all flasks/buffs, now
;   "e" and "r"      - buff skills (tracked like flasks)
;   Alt+C            - Ctrl-Click every location in the (I)nventory screen
;   Alt+M            - move items from stash (12x12 or 24x24) to inventory
;   Alt+D            - learn the hovered flask's duration from the game
;   Alt+G            - show/copy the current mouse screen coordinates
;   Alt+H            - two-point grid calibration (origin + cell step)
;   Alt+S            - swap a skill gem with an alternate
;   Ctrl+Alt+R       - reload this script after editing it (works
;                      anywhere, not just in game)
;
; The inventory/stash/gem coordinates below are resolution specific -
; calibrate them with Alt+G before using Alt+C / Alt+M / Alt+S.
;----------------------------------------------------------------------

; v1 default send mode + key delay, so timing matches the original script.
; If PoE occasionally misses a keypress, try SetKeyDelay(10, 10).
SendMode("Event")
SetKeyDelay(10, -1)

; All coordinates in this script are screen coordinates, for both
; MouseGetPos (Alt+G) and every Click - so what Alt+G shows is exactly
; what you paste into the config below.
CoordMode("Mouse", "Screen")
CoordMode("ToolTip", "Screen")   ; so the status indicator sits at a fixed spot

; v1's default title match mode ("starts with"), so #HotIf behaves as before.
SetTitleMatchMode(1)

;----------------------------------------------------------------------
; Crash diagnostics.
;
; An uncaught error in v2 normally pops a modal dialog. Over a fullscreen
; game that reads as a freeze, and choosing "Exit" on it kills the script
; with no trace. Instead we append the error to a log next to this file
; and show a non-focus-stealing tooltip, so the game is never interrupted
; and there is always a record of what happened.
;----------------------------------------------------------------------
LogFile := A_ScriptDir "\PoEAutoFlask.log"
OnError(LogError)
LogLine("--- script started (AHK " A_AhkVersion ", screen " A_ScreenWidth "x" A_ScreenHeight ") ---")

;----------------------------------------------------------------------
; Window the macro is allowed to act in. Use "ahk_exe PathOfExile.exe"
; instead if you want to be stricter, or "Path of Exile 2" for PoE2.
;----------------------------------------------------------------------
PoEWindow := "Path of Exile"

;----------------------------------------------------------------------
; Set the duration of each flask, in ms, below. For example, if the
; flask in slot 3 has a duration of "Lasts 4.80 Seconds", then use:
;       3, 4800
;
; To disable a particular flask, set its duration to 0.
; The "e" / "r" entries are for temporary buff skills on those slots.
;----------------------------------------------------------------------
FlaskDurationInit := Map(
    1  , 5000,
    2  , 5000,
    3  , 5000,
    4  , 5000,
    5  , 5000,
    "e", 4500,          ; buff skill on "e" (Steelskin in the original)
    "r",    0           ; buff skill on "r" (Molten Shell); 0 = disabled
)

; The order flasks/buffs are checked and fired in. Remove a key here to
; stop the macro touching that slot entirely.
FlaskOrder := [1, 2, 3, 4, 5, "e", "r"]

;----------------------------------------------------------------------
; Learned durations are stored here and override the values above, so
; you never have to hand-edit this file again. See Alt+D.
;----------------------------------------------------------------------
IniFile := A_ScriptDir "\PoEAutoFlask.ini"
LoadedCount := LoadDurations()

;----------------------------------------------------------------------
; Runtime state
;----------------------------------------------------------------------
FlaskDuration  := Map()     ; current (jittered) duration per slot
FlaskLastUsed  := Map()     ; A_TickCount of last use per slot
UseFlasks      := false
HoldRightClick := false
LastRightClick := 0
StashGui       := ""

; Pause between generated clicks in the inventory/stash sweeps. The v1
; script had none; a small delay stops PoE dropping clicks.
ClickDelay := 25

;----------------------------------------------------------------------
; Where the persistent "auto-flasks ON" indicator sits, in screen
; coordinates. It stays on screen the whole time auto-flasks are enabled
; and disappears when you toggle them off, so the label is always an
; honest answer to "is this thing armed?".
;
; Defaults to the top-left corner; move it wherever it isn't in the way.
;----------------------------------------------------------------------
StatusX := 40
StatusY := 40

;======================================================================
; SCREEN COORDINATES - tuned for 3840x2160 (4K)
;
; The upstream script's numbers were for 2560x1440; everything below is
; those values x1.5. That is the right transform *if* PoE's UI scales
; proportionally, which it does when the in-game UI Scale slider is at
; the same setting - but it is still a starting point, not gospel.
; Verify with Alt+G (reads the mouse position) or Alt+H (two-point grid
; helper, see below) and correct anything that is off.
;
; Deltas may be fractional - that is intentional. Positions are computed
; as origin + n*step and rounded at click time, so error never adds up
; across a 24-row quad stash.
;======================================================================

;----------------------------------------------------------------------
; Fast ctrl-click from the Inventory screen using Alt+C. InvX/InvY are
; the centre of the top-left inventory cell; InvDelta is the pixel step
; to the next cell, right or down. (These were ix/iy/delta in v1.)
;
; To recalibrate: open the Inventory (I), hover the centre of the
; top-left cell and press Alt+H, then hover the cell one right and one
; down and press Alt+H again. It prints and copies origin + deltas.
;----------------------------------------------------------------------
InvX     := 2595        ; 1730 * 1.5
InvY     := 1227        ;  818 * 1.5
InvDelta :=  105        ;   70 * 1.5

;----------------------------------------------------------------------
; The following are used for fast ctrl-click from stash tabs into the
; inventory screen, using Alt+M. Index 1 is the 12x12 stash, index 2 is
; the 24x24 "Quad" stash. Calibrate with Alt+G as above, but using the
; stash tab boxes.
;
; StashX is kept for reference only - the sweep starts wherever the
; mouse is when you press Alt+M. StashY is the top of a stash column,
; used when the sweep wraps to the next column.
;----------------------------------------------------------------------
StashX    := [   90,    60]     ; [ 60,  40] * 1.5   (reference only)
StashY    := [379.5,   351]     ; [253, 234] * 1.5
StashD    := [  105,  52.5]     ; [ 70,  35] * 1.5   (quad step is fractional)
StashSize := [   12,    24]     ; grid size, not a coordinate - unscaled

;----------------------------------------------------------------------
; The following are used for gem swapping. Useful when you use one skill
; for clearing and another for bossing.
; Put the coordinates of your primary attack skill in PrimX, PrimY.
; Put the coordinates of your alternate attack skill in AltX, AltY.
; WeaponSwap determines if the alt gem is in the inventory or in the
; alternate weapon set.
;----------------------------------------------------------------------
PrimX := 3120       ; 2080 * 1.5
PrimY :=  501       ;  334 * 1.5
AltX  := 3758       ; 2505 * 1.5
AltY  := 1230       ;  820 * 1.5
WeaponSwap := false

;----------------------------------------------------------------------
; Main program loop - we use flasks whenever flask usage is enabled via
; hotkey (default Alt+F12), and we've attacked within the last 0.5
; seconds (or are channeling/continuous attacking).
;
; The v1 version had no Sleep here and pinned a CPU core at 100%.
;----------------------------------------------------------------------
; If this run came from Ctrl+Alt+R, pick the armed state back up.
RearmAfterReload()

Loop {
    Sleep(10)

    if (!UseFlasks)
        continue

    ; Never fire keys into another window if you alt-tab out mid-fight.
    if (!WinActive(PoEWindow))
        continue

    ; Have we attacked in the last 0.5 seconds, or are we holding the
    ; button down for a continuous/channelled skill?
    if (((A_TickCount - LastRightClick) < 500) || HoldRightClick)
        CycleAllFlasksWhenReady()
}

;======================================================================
; Hotkeys - only active while Path of Exile is the foreground window
;======================================================================
#HotIf WinActive(PoEWindow)

!F12:: {
    global UseFlasks
    SetAutoFlasks(!UseFlasks)
}

;----------------------------------------------------------------------
; To use a different mouse button, change "RButton" below to LButton or
; MButton. Change it in both places (press and release). If you attack
; with a keyboard key instead, use e.g. ~q:: and ~q Up::
;----------------------------------------------------------------------
~RButton:: {
    global HoldRightClick, LastRightClick
    ; pass-thru, and record when the last attack happened; we also track
    ; whether the button is held for continuous/channelled skills
    HoldRightClick := true
    LastRightClick := A_TickCount
}

~RButton Up:: {
    global HoldRightClick
    HoldRightClick := false
}

;----------------------------------------------------------------------
; Manual use of flasks/buffs, while still tracking optimal recast times.
;----------------------------------------------------------------------
~1::MarkSlotUsed(1)
~2::MarkSlotUsed(2)
~3::MarkSlotUsed(3)
~4::MarkSlotUsed(4)
~5::MarkSlotUsed(5)
~e::MarkSlotUsed("e")
~r::MarkSlotUsed("r")

;----------------------------------------------------------------------
; Use all flasks, now. A variable delay is included between flasks.
; NOTE: this uses every slot in FlaskOrder, even those with a duration
; of 0. The hotkey below is the backtick key (left of "1" on a US
; keyboard); if your layout puts something else there, use SC029::
; instead to bind the same physical key.
;----------------------------------------------------------------------
`:: {
    global UseFlasks, FlaskOrder

    if (!UseFlasks)
        return

    for _, key in FlaskOrder {
        Send("{" key "}")
        MarkSlotUsed(key)   ; so the auto-cycle doesn't instantly re-fire it
        Sleep(Random(0, 99))
    }
}

;----------------------------------------------------------------------
; Alt+C - Ctrl-Click every location in the (I)nventory screen.
;----------------------------------------------------------------------
!c:: {
    global InvX, InvY, InvDelta, ClickDelay

    Loop 12 {
        col := Round(InvX + (A_Index - 1) * InvDelta)
        Loop 5 {
            row := Round(InvY + (A_Index - 1) * InvDelta)
            Send("^{Click " col " " row "}")
            Sleep(ClickDelay)
        }
    }
}

;----------------------------------------------------------------------
; Alt+M - move items from a stash tab (12x12 or 24x24) to the inventory.
;
; Put the mouse pointer over the first stash box you want to move, THEN
; press Alt+M - the start position is captured at that moment, so you
; can safely click OK with the mouse.
;
; "Clicks" is how many items to move. "Mouse is in Row" is which row of
; the stash tab the pointer is starting from.
;----------------------------------------------------------------------
!m:: {
    global StashGui

    MouseGetPos(&startX, &startY)

    if (StashGui)
        try StashGui.Destroy()

    StashGui := Gui("+AlwaysOnTop +OwnDialogs", "Stash -> Inventory")
    rbNorm := StashGui.AddRadio("Checked", "Norm Stash Tab (12x12)")
    StashGui.AddRadio(, "Quad Stash Tab (24x24)")

    StashGui.AddText(, "&Clicks:")
    StashGui.AddEdit("w50")
    udClicks := StashGui.AddUpDown("Range1-50", 50)

    StashGui.AddText(, "Mouse is in &Row:")
    StashGui.AddEdit("w50")
    udRow := StashGui.AddUpDown("Range1-24", 1)

    StashGui.AddText(, "Starting at: " startX ", " startY)
    btnOK := StashGui.AddButton("Default w90", "OK")

    btnOK.OnEvent("Click", RunMove)
    StashGui.OnEvent("Escape", CancelMove)
    StashGui.OnEvent("Close",  CancelMove)
    StashGui.Show()

    RunMove(*) {
        selStash := rbNorm.Value ? 1 : 2
        clicks   := udClicks.Value
        startRow := udRow.Value
        CancelMove()
        MoveStashItems(startX, startY, selStash, clicks, startRow)
    }

    CancelMove(*) {
        global StashGui
        if (StashGui) {
            StashGui.Destroy()
            StashGui := ""
        }
    }
}

;----------------------------------------------------------------------
; Alt+G - get the current screen coordinates of the mouse pointer.
;----------------------------------------------------------------------
!g:: {
    MouseGetPos(&x, &y)
    A_Clipboard := x ", " y
    Notify(x ", " y "`n(copied to clipboard)", 4000)
}

;----------------------------------------------------------------------
; Alt+D - learn a flask's duration straight from the game.
;
; Hover flask 1 in your inventory and press Alt+D. The script uses PoE's
; own "copy item text" feature (Ctrl+C on a hovered item - the same one
; trade sites use; no memory reading), parses the duration out of it,
; saves it to PoEAutoFlask.ini and moves on to flask 2. Five presses and
; every flask is configured.
;
; The full copied item text is written to the log every time, so if a
; duration cannot be parsed the raw text is available to work from.
;
; Note: this reads the DURATION PRINTED ON THE ITEM. Passive tree and
; ascendancy "increased Flask Effect Duration" is not on the item, so if
; you have any, the real duration is longer than what this learns.
;----------------------------------------------------------------------
!d:: {
    static slot := 1
    global FlaskDurationInit, FlaskDuration, UseFlasks

    saved := A_Clipboard
    A_Clipboard := ""
    Send("^c")
    gotItem := ClipWait(1, 0)
    text := gotItem ? A_Clipboard : ""
    A_Clipboard := saved

    if (!gotItem || Trim(text) = "") {
        Notify("Nothing copied.`nHover flask " slot " in your INVENTORY, then press Alt+D.", 5000)
        return
    }

    LogLine("Alt+D slot " slot " copied item text:`n" text)

    r := ParseFlaskDuration(text)
    if (!r.ok) {
        Notify("No duration found in that item.`nRaw text saved to PoEAutoFlask.log`nStill on flask " slot ".", 6000)
        return
    }

    msg := "Flask " slot " = " r.ms " ms   (matched: " r.raw ")"

    if (RegExMatch(text, "i)\b(Life|Mana|Hybrid) Flask\b"))
        msg .= "`nWARNING: life/mana/hybrid flask - this macro is for buff flasks only."

    FlaskDurationInit[slot] := r.ms
    SaveDuration(slot, r.ms)
    if (UseFlasks && FlaskDuration.Has(slot))
        FlaskDuration[slot] := r.ms          ; take effect without re-arming

    if (slot >= 5) {
        slot := 1
        msg .= "`nAll 5 flasks learned and saved."
    } else {
        slot++
        msg .= "`nNow hover flask " slot " and press Alt+D."
    }

    Notify(msg, 5000)
    if (UseFlasks)
        ShowStatus(true)
}

;----------------------------------------------------------------------
; Alt+H - two-point grid calibration, for the inventory or a stash tab.
;
; Press once to arm, hover the centre of the TOP-LEFT cell and press
; again, then hover the cell one RIGHT and one DOWN and press a third
; time. It reports the origin and the X/Y step, and copies them to the
; clipboard ready to paste into the config at the top of this file.
;----------------------------------------------------------------------
!h:: {
    static stage := 0
    static x1 := 0, y1 := 0

    stage++
    if (stage = 1) {
        Notify("Calibrate: hover the TOP-LEFT cell, then press Alt+H", 6000)
        return
    }

    if (stage = 2) {
        MouseGetPos(&x1, &y1)
        Notify("Origin " x1 ", " y1 "`nNow hover the cell one RIGHT and one DOWN, press Alt+H", 6000)
        return
    }

    MouseGetPos(&x2, &y2)
    stage := 0

    dx := x2 - x1
    dy := y2 - y1
    if (dx <= 0 || dy <= 0) {
        Notify("Second point must be right of and below the first. Cancelled.", 4000)
        return
    }

    result := "X := " x1 "   Y := " y1 "   DeltaX := " dx "   DeltaY := " dy
    A_Clipboard := result
    Notify(result "`n(copied to clipboard)", 8000)
}

;----------------------------------------------------------------------
; Alt+S - swap a skill gem with an alternate. Gems must be the same
; colour if the alt weapon slot is used for holding gems.
;----------------------------------------------------------------------
!s:: {
    global PrimX, PrimY, AltX, AltY, WeaponSwap

    MouseGetPos(&x, &y)     ; save the current mouse position
    Send("i")
    Sleep(100)
    Click(PrimX, PrimY, "Right")
    Sleep(100)
    if (WeaponSwap) {
        Send("{x}")
        Sleep(100)
    }
    Click(AltX, AltY)
    Sleep(100)
    if (WeaponSwap) {
        Send("{x}")
        Sleep(100)
    }
    Click(PrimX, PrimY)
    Sleep(100)
    Send("i")
    Sleep(100)
    MouseMove(x, y)
}

#HotIf

;----------------------------------------------------------------------
; Ctrl+Alt+R - reload the script after the file has been edited.
;
; Deliberately OUTSIDE the #HotIf block, because you will usually be in
; an editor rather than in the game when you want this. Re-reads both
; this file and PoEAutoFlask.ini, and restores the armed state so a
; reload mid-session doesn't silently disarm your flasks.
;----------------------------------------------------------------------
^!r::ReloadScript()

;======================================================================
; Functions
;======================================================================

;----------------------------------------------------------------------
; Arm or disarm auto-flasks. Shared by Alt+F12 and the reload restore,
; so both paths reset the timers identically.
;----------------------------------------------------------------------
SetAutoFlasks(on) {
    global UseFlasks, FlaskDuration, FlaskLastUsed, FlaskDurationInit, FlaskOrder

    UseFlasks := on
    if (!on) {
        ShowStatus(false)
        Notify("Auto-flasks OFF", 1500)
        return
    }

    ; reset usage timers for all flasks
    FlaskDuration := Map()
    FlaskLastUsed := Map()
    for _, key in FlaskOrder {
        FlaskLastUsed[key] := 0
        FlaskDuration[key] := FlaskDurationInit.Has(key) ? FlaskDurationInit[key] : 0
    }
    ShowStatus(true)
}

;----------------------------------------------------------------------
; Reload, remembering whether flasks were armed.
;----------------------------------------------------------------------
ReloadScript() {
    global IniFile, UseFlasks

    try IniWrite(UseFlasks ? 1 : 0, IniFile, "State", "RearmOnReload")
    LogLine("--- reloading (armed=" (UseFlasks ? 1 : 0) ") ---")
    Reload()
}

;----------------------------------------------------------------------
; Re-arm after an explicit reload, but NOT on a cold start - the marker
; is consumed as soon as it is read, so launching the script fresh
; always begins disarmed.
;----------------------------------------------------------------------
RearmAfterReload() {
    global IniFile

    rearm := 0
    try rearm := IniRead(IniFile, "State", "RearmOnReload", 0)
    try IniDelete(IniFile, "State", "RearmOnReload")

    if (rearm = 1) {
        SetAutoFlasks(true)
        Notify("Reloaded - flasks re-armed", 2000)
    }
}

;----------------------------------------------------------------------
; Fire every flask/buff whose effect has expired.
;----------------------------------------------------------------------
CycleAllFlasksWhenReady() {
    global FlaskOrder, FlaskDuration, FlaskLastUsed

    for _, key in FlaskOrder {
        if (!FlaskDuration.Has(key))
            continue

        duration := FlaskDuration[key]

        ; skip slots with 0 duration, and slots that are still active
        if (duration > 0 && duration < A_TickCount - FlaskLastUsed[key]) {
            Send("{" key "}")
            jitter := MarkSlotUsed(key)
            Sleep(jitter > 0 ? jitter : 0)
        }
    }
}

;----------------------------------------------------------------------
; Record that a slot was just used, and randomise its duration by
; +/-99 ms to simulate human timing. Returns the jitter applied.
;----------------------------------------------------------------------
MarkSlotUsed(key) {
    global FlaskDuration, FlaskDurationInit, FlaskLastUsed

    if (!FlaskDurationInit.Has(key))
        return 0

    jitter := Random(-99, 99)
    FlaskLastUsed[key] := A_TickCount
    FlaskDuration[key] := FlaskDurationInit[key] + jitter
    return jitter
}

;----------------------------------------------------------------------
; Ctrl-click `clicks` stash cells, walking down a column and wrapping to
; the next column when the bottom of the tab is reached.
;----------------------------------------------------------------------
MoveStashItems(startX, startY, selStash, clicks, startRow) {
    global StashY, StashD, StashSize, ClickDelay

    step := StashD[selStash]        ; may be fractional (52.5 for quad)
    topY := StashY[selStash]
    rows := StashSize[selStash]

    col     := 0                    ; columns moved right of the start column
    rowIdx  := startRow             ; 1-based row within the tab
    baseRow := startRow             ; row that baseY corresponds to
    baseY   := startY

    Loop clicks {
        ; computed from the origin each time, so rounding never accumulates
        x := Round(startX + col * step)
        y := Round(baseY + (rowIdx - baseRow) * step)

        Send("^{Click " x " " y "}")
        Sleep(ClickDelay)

        ; past the bottom of the tab - wrap to the top of the next column
        if (++rowIdx > rows) {
            rowIdx  := 1
            baseRow := 1
            baseY   := topY
            col     += 1
        }
    }
}

;----------------------------------------------------------------------
; Pull a flask duration out of PoE's copied item text.
;
; The wording has changed across leagues, so several forms are tried in
; order of specificity, and quality/affix markers like "(augmented)" are
; tolerated between the number and the word "seconds":
;     Lasts 4.20 Seconds
;     Duration: 5.04 (augmented) seconds
; The last pattern is a loose fallback for any "<n> seconds".
;----------------------------------------------------------------------
ParseFlaskDuration(text) {
    patterns := [
        "i)Lasts\s+([\d.]+)\s*(?:\([^)]*\)\s*)?Seconds",
        "i)Duration\s*:?\s*([\d.]+)\s*(?:\([^)]*\)\s*)?Seconds",
        "i)([\d.]+)\s*(?:\([^)]*\)\s*)?Seconds"
    ]

    for _, pat in patterns {
        if (!RegExMatch(text, pat, &m))
            continue
        if (!IsNumber(m[1]))
            continue
        secs := m[1] + 0
        ; sanity: a flask that lasts 0 or over a minute is a bad parse
        if (secs > 0 && secs < 60)
            return {ok: true, ms: Round(secs * 1000), raw: Trim(m[0])}
    }
    return {ok: false, ms: 0, raw: ""}
}

;----------------------------------------------------------------------
; Learned durations, persisted next to the script so they survive edits
; and updates to this file.
;----------------------------------------------------------------------
LoadDurations() {
    global IniFile, FlaskDurationInit, FlaskOrder

    if (!FileExist(IniFile))
        return 0

    n := 0
    for _, key in FlaskOrder {
        v := ""
        try v := IniRead(IniFile, "Durations", key, "")
        if (v != "" && IsNumber(v)) {
            FlaskDurationInit[key] := Integer(v)
            n++
        }
    }
    return n
}

SaveDuration(key, ms) {
    global IniFile
    try IniWrite(ms, IniFile, "Durations", key)
}

;----------------------------------------------------------------------
; Append a timestamped line to the log file. Never throws - a logging
; failure must not take the script down.
;----------------------------------------------------------------------
LogLine(text) {
    global LogFile
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  " text "`n", LogFile, "UTF-8")
}

;----------------------------------------------------------------------
; Called for any uncaught error. Logs the details, shows a tooltip, and
; returns 1 to suppress the modal dialog that would otherwise sit on top
; of the game. The offending thread still ends; the script keeps running.
;----------------------------------------------------------------------
LogError(err, mode) {
    detail := "unknown error"
    try detail := err.Message
    line := "?", what := "?", extra := ""
    try line := err.Line
    try what := err.What
    try extra := err.Extra

    LogLine("ERROR: " detail "  (in " what ", line " line ")" (extra ? "  extra=" extra : ""))
    try LogLine("  stack: " StrReplace(err.Stack, "`n", " | "))

    Notify("Script error, logged:`n" detail "`nline " line, 6000)
    return 1    ; suppress the dialog - do not interrupt the game
}

;----------------------------------------------------------------------
; Persistent on-screen state indicator.
;
; Uses tooltip slot 2 so the transient messages from Notify() (slot 1)
; can never overwrite or clear it. Also mirrors the state onto the tray
; icon tooltip, which is readable even if the game is drawing over the
; on-screen one.
;----------------------------------------------------------------------
ShowStatus(on) {
    global StatusX, StatusY, FlaskOrder, FlaskDurationInit

    if (!on) {
        ToolTip(, , , 2)                    ; clear slot 2
        A_IconTip := "PoE AutoFlask - OFF"
        return
    }

    ; list which slots will actually fire, so the label is informative
    active := ""
    for _, key in FlaskOrder
        if (FlaskDurationInit.Has(key) && FlaskDurationInit[key] > 0)
            active .= (active ? "," : "") key

    label := "AUTO-FLASKS ON  [" (active ? active : "nothing enabled!") "]"
    ToolTip(label, StatusX, StatusY, 2)
    A_IconTip := "PoE AutoFlask - ON (" active ")"
}

;----------------------------------------------------------------------
; Transient tooltip (slot 1) that clears itself after `ms`.
;----------------------------------------------------------------------
Notify(text, ms := 1500) {
    ToolTip(text, , , 1)
    SetTimer(ClearToolTip, -ms)
}

ClearToolTip() {
    ToolTip(, , , 1)
}
