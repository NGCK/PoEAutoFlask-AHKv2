# Changes from the original

Port notes for [JoelStanford/PoEAutoFlask](https://github.com/JoelStanford/PoEAutoFlask) → AutoHotkey v2.

Three kinds of change are mixed together below, kept separate on purpose: **mechanical** changes forced by v2 syntax, **behavioural** fixes where the original did something wrong, and **new** functionality that has no v1 equivalent.

---

## Why a port was needed

AutoHotkey v2 is not backwards compatible. The original script does not run on it — it fails at load, not at runtime, so there is no partial-functionality middle ground. Commands became functions, expression syntax changed, variable scoping in functions changed, and the object model was rewritten. Every one of those touches this script.

---

## Mechanical — v2 syntax

| Area | v1 | v2 |
|---|---|---|
| Commands | `MouseGetPos, x, y` | `MouseGetPos(&x, &y)` — functions, reference params |
| Clipboard | `Clipboard` | `A_Clipboard` |
| Clipboard wait | `ClipWait, 1, 0` | `ClipWait(1, 0)` |
| Random | `Random, v, -99, 99` | `Random(-99, 99)` — returns a value |
| INI | `IniRead, v, file, ...` | `IniRead(file, ...)` |
| Numeric test | `if v is number` | `IsNumber(v)` |
| Associative data | `{1: 5000}` object literal | `Map(1, 5000, ...)` |
| GUI | `Gui, Add, Radio, ...` | `Gui()` object, `.AddRadio()`, `.OnEvent()` |
| Hotkeys | label + `return` | block `{ }` |
| Context | `#If WinActive(...)` | `#HotIf WinActive(...)` |

Two of these have consequences worth calling out:

**Maps, not objects.** Flask slots are a mix of integers (`1`–`5`) and strings (`"e"`, `"r"`). In v2 a plain object cannot hold that mix as keys the way v1's did, so all the per-slot state is `Map()`. This is why the code says `FlaskDuration.Has(key)` rather than testing for a blank value.

**Functions are local by default.** In v1, a function could read a global by name. In v2 it cannot, which is why every hotkey block and helper that touches shared state opens with an explicit `global` line. Those are load-bearing — deleting one silently creates a local variable that shadows the real one, and the symptom is state that mysteriously resets.

### The backtick hotkey

The "use everything now" hotkey is the backtick key. In v1 it had to be written escaped, as a doubled backtick. **v2 rejects that form** and wants a single backtick:

```autohotkey
`:: {
```

This looks like a typo and it is not. Do not "fix" it back to the doubled form — the script will not load.

---

## Runtime defaults that had to be restored

v2 changed several defaults out from under the script. Left alone, the port would have loaded fine and then behaved subtly differently — the worst failure mode. Four are pinned explicitly at the top of the file:

| Setting | v2 default | Pinned to | Why |
|---|---|---|---|
| `SendMode` | `Input` | `Event` | v1 timing. `Input` is faster but PoE tolerates it less well. |
| `SetKeyDelay` | — | `10, -1` | Matches the original's pacing. |
| `CoordMode "Mouse"` | `Client` | `Screen` | v1 was screen-relative. Without this every stored coordinate is wrong by the window offset. |
| `SetTitleMatchMode` | `2` (contains) | `1` (starts with) | v1 behaviour. Under `2`, `"Path of Exile"` would also match a browser tab about Path of Exile, and hotkeys would go live outside the game. |

`CoordMode "ToolTip"` is also set to `Screen`, which v1 did not need — see the status indicator below.

---

## Behavioural fixes

**The main loop pinned a CPU core at 100%.** v1's loop had no `Sleep`, so it spun as fast as the interpreter allowed. Now `Sleep(10)`, which is far below the resolution of anything being timed and costs nothing.

**Flask keys were sent to whatever window was in front.** The loop now re-checks `WinActive(PoEWindow)` on every pass. Previously, alt-tabbing out mid-fight with flasks armed meant your `1`–`5` keys kept firing into Discord, your browser, or whatever else had focus. The hotkeys were correctly context-limited; the loop was not.

**Generated clicks were sent with no gap, and PoE dropped them.** The inventory and stash sweeps now pause `ClickDelay` (25 ms, configurable) between clicks. Symptom of the old behaviour was a sweep that skipped cells at random.

**Rounding error accumulated across a stash sweep.** Positions are now computed as `origin + n × step` and rounded once, at click time, rather than stepping and rounding repeatedly. This did not bite at 1440p, where the Quad-stash step was a whole 35 px — but scaled ×1.5 it becomes `52.5`, and repeated rounding drifts by half a cell before the bottom of a 24-row tab.

**Uncaught errors killed the script silently.** v2 pops a modal dialog on an unhandled error. Over a fullscreen game that presents as a freeze, and the natural response — hitting Exit — terminates the script with no record of what went wrong. An `OnError` handler now writes the message, line, and stack to `PoEAutoFlask.log`, flashes a tooltip, and returns `1` to suppress the dialog. The offending thread ends; the script survives.

**`Alt+M` captured the mouse position too late.** The stash sweep's start point is now read at the instant the hotkey fires, before the dialog opens, so moving the pointer to click OK no longer moves the target.

---

## New in v2

None of these exist upstream.

### `Alt+D` — learn flask durations from the game

The original required you to hand-edit millisecond values into the script, which meant re-editing every time you swapped a flask. `Alt+D` hovers-and-reads instead: it uses PoE's own Ctrl+C item-copy, parses the duration out of the text, and saves it.

Duration wording has changed across leagues, so the parser tries three patterns in order of specificity — `Lasts 4.20 Seconds`, `Duration: 5.04 seconds`, then a loose `<n> seconds` fallback — and tolerates affix markers like `(augmented)` between the number and the unit. Anything parsing to 0 or over 60 seconds is rejected as a bad match. The full copied text goes to the log every time, so a parse failure leaves you able to read the real number off manually.

**No memory reading is involved.** The item-copy hotkey is a feature PoE exposes deliberately.

### Persisted settings

`PoEAutoFlask.ini` holds learned durations, so they survive restarts *and* edits to the script. Values in the INI override `FlaskDurationInit` in the source.

### Re-arm across reload

`Ctrl+Alt+R` reloads the script and restores whether flasks were armed, so editing mid-session does not silently disarm you. The marker is consumed as it is read, so a *cold* start always begins disarmed — you never come back to a machine that is already firing keys.

This hotkey is intentionally outside the `#HotIf WinActive` block, since you are usually in an editor when you want it.

### Persistent status indicator

A label sits on screen for as long as auto-flasks are armed, listing which slots are actually live, and disappears when you disarm. It uses tooltip slot 2 so transient messages (slot 1) can never overwrite or clear it, and mirrors onto the tray icon tooltip, which stays readable when the game draws over the on-screen one.

"Is this thing armed?" now has an honest answer at a glance. v1's toggle was silent.

### `Alt+H` — two-point grid calibration

v1 had `Alt+G` for reading a single coordinate. `Alt+H` derives a whole grid: hover the top-left cell, then the cell one right and one down, and it works out both the origin and the per-cell step and copies all four numbers ready to paste.

### Slot control

`FlaskOrder` sets which slots are touched and in what order. Removing a key stops the script touching that slot at all — distinct from setting its duration to `0`, which keeps it in the ordering but skips it during auto-cycling.

---

## Known limitations

**Screen coordinates are unverified.** All coordinates are the original's 2560×1440 values × 1.5 for 3840×2160. The transform is correct if PoE's UI scales proportionally, but none of it has been checked against a running client. `Alt+G` and `Alt+H` exist to fix them. Flask automation itself uses no coordinates and is unaffected.

**Shipped flask durations are placeholders.** All five are `5000` ms — a round number to occupy the slot, not a measurement, and not a sensible default for any real build. `Alt+D` is the intended way to set them.

**`Alt+D` under-reads with tree-based flask duration.** It reads the duration printed on the item; passive-tree and ascendancy "increased Flask Effect Duration" is not in the item text and cannot be seen. It errs safe — the script re-presses early, spending charges for uptime — but if you are charge-starved, raise the numbers by hand.

**Buff flasks only.** Life, Mana, and Hybrid flasks want to fire on health, not a timer. `Alt+D` warns if it sees one; it does not refuse.

**`Alt+D` covers slots 1–5 only.** `e` and `r` are skills, not items, so there is no text to read — set them in `FlaskDurationInit`.

**The backtick hotkey fires every slot in `FlaskOrder`,** including `0`-duration ones. Deliberate — it means "use everything now" — but a disabled slot still receives a keypress.

---

## Not changed

The core design is Joel Stanford's and is untouched: cycling flasks on tracked per-slot timers, gated on having attacked in the last 500 ms or holding the attack button for a channelled skill; ±99 ms jitter on each duration; pass-through tracking of manual presses so manual and automatic use stay in sync; and the inventory, stash, and gem-swap helpers.
