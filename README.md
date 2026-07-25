# PoEAutoFlask — AutoHotkey **v2**

Automatic buff-flask uptime for Path of Exile.

![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2.0%2B-334455?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows-0078D6?style=flat-square)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-NGCK-FFDD00?style=flat-square&logo=buymeacoffee&logoColor=black)](https://www.buymeacoffee.com/NGCK)

If this saved you some finger pain, you can [buy me a coffee](https://www.buymeacoffee.com/NGCK) ☕ — entirely optional, the script is free either way.

---

This is an **AutoHotkey v2** port of [JoelStanford/PoEAutoFlask](https://github.com/JoelStanford/PoEAutoFlask), which was written for AutoHotkey v1 and will not run on v2 without changes. If you have already migrated to AHK v2 and found the original script erroring out on load, this is the version you want.

It keeps your buff flasks up while you are actually fighting: whenever you have attacked in the last half second (or are holding the attack button for a channelled skill), it re-presses any flask whose effect has expired. It does nothing while you are running around town.

Along the way it also carries a set of quality-of-life helpers ported from the original — bulk inventory/stash ctrl-clicking, gem swapping, and coordinate calibration — plus some things v1 did not have, most usefully **the ability to learn your flask durations from the game itself** instead of you hand-editing numbers into the script.

---

## ⚠️ Read this before you use it

**Input automation is against Grinding Gear Games' Terms of Service, and accounts have been actioned for it.** GGG's stated position is that one keypress should produce one game action. This script presses keys on your behalf, so it does not meet that bar. Whether you run it is your call, but run it understanding that the risk is a ban, and that the risk is yours alone.

That said, it is worth being precise about what this script does and does not do:

- **It does not read or write game memory.** There is no injection, no DLL, no process handle, no packet manipulation.
- **It sends keystrokes and mouse clicks**, the same as a macro keyboard would.
- **It reads item text only through PoE's own "copy item" feature** — the Ctrl+C on a hovered item that the game exposes deliberately, and that every trade site relies on. That is the sole channel through which the script learns anything about your character.

That distinction matters for understanding the mechanism. It does **not** make the script ToS-compliant.

---

## Requirements

- **Windows**
- **[AutoHotkey v2.0](https://www.autohotkey.com/) or newer** — v1 will not run this file; the `#Requires AutoHotkey v2.0` directive at the top will stop it cleanly if you try
- Path of Exile (the window-title match also works for PoE 2 with a one-line change — see [Targeting a different game window](#targeting-a-different-game-window))

## Install

```bash
git clone https://github.com/NGCK/PoEAutoFlask-AHKv2.git
```

Or just download `PoEAutoFlask_v2.ahk` on its own — it is a single self-contained file with no dependencies.

Double-click the `.ahk` to run it. The script starts **disarmed**; nothing happens until you turn it on in-game with `Alt+F12`.

## Quick start

1. Launch PoE and the script.
2. Open your inventory, hover flask 1, press **`Alt+D`**. Repeat for flasks 2–5 — it walks you through them and saves as it goes. *(Do this once; it persists.)*
3. In-game, press **`Alt+F12`** to arm. An `AUTO-FLASKS ON` label appears in the top-left listing which slots are live.
4. Fight. Flasks maintain themselves.
5. **`Alt+F12`** again to disarm — the label disappears, which is your confirmation.

---

## Hotkeys

All hotkeys except `Ctrl+Alt+R` only fire while Path of Exile is the **active** window.

| Key | Does |
|---|---|
| `Alt+F12` | Arm / disarm automatic flask usage |
| `` ` `` (backtick) | Use every flask and buff **right now** |
| `1`–`5` | Normal flask use, but the timer is tracked so auto-cycling stays in sync |
| `e` / `r` | Same, for buff skills on those keys |
| Right mouse | Your attack — passed straight through, only *observed* to know when you are fighting |
| `Alt+D` | Learn the hovered flask's duration from the game and save it |
| `Alt+G` | Show and copy the mouse's current screen coordinates |
| `Alt+H` | Two-point grid calibration (origin + cell step) |
| `Alt+C` | Ctrl-click every cell in the inventory screen |
| `Alt+M` | Move items from a stash tab into your inventory |
| `Alt+S` | Swap a skill gem with an alternate |
| `Ctrl+Alt+R` | Reload the script after editing it — **works anywhere**, not just in game |

`Ctrl+Alt+R` deliberately sits outside the in-game restriction, because you are usually in a text editor when you want it. It remembers whether flasks were armed and re-arms them, so a reload mid-session does not silently leave you unprotected. A *cold* start always begins disarmed.

---

## Setting your flask durations

The script re-presses a flask once its effect has run out, so it needs to know how long each one lasts.

**The intended way is `Alt+D`.** Open your inventory, hover flask 1, press `Alt+D`. The script copies the item text, parses the duration, writes it to `PoEAutoFlask.ini`, and tells you to move to flask 2. Five presses and you are configured. The values persist across restarts and across edits to the script.

The durations shipped in the file are all `5000` ms. **That is a placeholder, not a measurement** — it is not a sane default for any particular build, it is just a round number to occupy the slot until `Alt+D` fills it in. Use `Alt+D`.

If you would rather set them by hand, edit `FlaskDurationInit` near the top of the script. A duration of `0` disables that slot entirely. Note that `PoEAutoFlask.ini` **overrides** the values in the file, so if you have ever run `Alt+D` you need to edit the INI (or delete it) for hand-edits to take effect.

> **`Alt+D` under-reads if you have flask duration on your tree.**
> It reads the duration *printed on the item*. Passive-tree and ascendancy "increased Flask Effect Duration" is not part of the item text, so it cannot be seen. If you have any, your real duration is longer than what gets learned.
>
> This errs in the safe direction — the script re-presses **early**, so you get uptime at the cost of some extra charges. If you are charge-starved, raise the learned numbers manually to match your actual tree.

**Buff flasks only.** This is for utility flasks — Quicksilver, Granite, Jade, Diamond, and so on. It is not for Life, Mana, or Hybrid flasks, which want to fire on *health*, not on a timer. `Alt+D` will warn you if it spots one, but it will not stop you.

`Alt+D` covers slots 1–5. The `e` and `r` buff-skill slots are hand-set in `FlaskDurationInit` — they are skills, not items, so there is no item text to read.

---

## Screen coordinates

> **The coordinates in this file are unverified.**
> The original script's numbers were for **2560×1440**. Everything here is those values **×1.5**, for **3840×2160**. That is the correct transform *if* PoE's UI scales proportionally — which it does when the in-game UI Scale slider is in the same place — but none of it has been checked against a running client. Treat it as a starting point, not a tested configuration.

This only affects `Alt+C`, `Alt+M`, and `Alt+S`. **Flask automation does not use coordinates at all** and works at any resolution.

Two tools to fix them:

- **`Alt+G`** — prints and copies the mouse's current screen position. Hover a thing, press it, paste the number in.
- **`Alt+H`** — two-point grid calibration, which is the faster option for grids. Press once to arm, hover the centre of the **top-left** cell and press again, then hover the cell **one right and one down** and press a third time. It works out the origin and the per-cell step and copies all four numbers to your clipboard.

Then paste into the config block:

| Setting | Controls |
|---|---|
| `InvX` / `InvY` / `InvDelta` | Inventory grid — origin and cell step (`Alt+C`) |
| `StashY` / `StashD` / `StashSize` | Stash tabs — index 1 is 12×12, index 2 is 24×24 Quad (`Alt+M`) |
| `PrimX` / `PrimY` / `AltX` / `AltY` | Primary and alternate gem sockets (`Alt+S`) |
| `StatusX` / `StatusY` | Where the `AUTO-FLASKS ON` label sits |

Everything is in **screen** coordinates, consistently — what `Alt+G` shows you is exactly what goes in the config, with no conversion.

Fractional step values (the Quad stash step is `52.5`) are intentional and fine. Positions are computed as `origin + n × step` and rounded only at click time, so rounding error never accumulates down a 24-row tab.

---

## The other helpers

### `Alt+C` — empty your inventory

Ctrl-clicks all 60 inventory cells, top-left to bottom-right. Useful for dumping a full inventory into a stash tab in one go.

### `Alt+M` — pull items out of a stash tab

Hover the first stash cell you want, **then** press `Alt+M`. The start position is captured at the moment you press the key, so the dialog that opens is safe to click with the mouse — moving the pointer to hit OK will not move the target.

Set the tab type (12×12 or 24×24 Quad), how many cells to sweep, and which row you started on. It walks down the column and wraps to the top of the next one when it reaches the bottom of the tab.

### `Alt+S` — swap a skill gem

Swaps your primary attack gem with an alternate — for example a clearing skill and a bossing skill. Set `PrimX`/`PrimY` to the primary socket and `AltX`/`AltY` to where the alternate lives.

Set `WeaponSwap := true` if the alternate gem is in your **swapped weapon set** rather than your inventory; the script will then press `x` to swap weapons at the right points. If both gems are socketed in the same weapon set, gem colour has to match.

---

## Targeting a different game window

`PoEWindow := "Path of Exile"` near the top controls which window the hotkeys are live in. Matching is "starts with", so:

- `"Path of Exile 2"` — PoE 2
- `"ahk_exe PathOfExile.exe"` — stricter, matches the process instead of the title

## Files the script writes

Both land next to the `.ahk` and are gitignored:

- **`PoEAutoFlask.ini`** — learned flask durations, plus a one-shot marker used to re-arm across `Ctrl+Alt+R`
- **`PoEAutoFlask.log`** — errors, and the full item text from every `Alt+D`

The log is the first place to look when something misbehaves. If `Alt+D` fails to find a duration, the raw copied text is in there and you can read off the real number.

---

## Troubleshooting

**The script will not start.** You are on AutoHotkey v1. This file requires v2 — see [Requirements](#requirements).

**Flasks do nothing.** Check in order: is it armed (`Alt+F12` — is the label showing)? Is PoE the active window? Are you actually attacking — it only fires when you have right-clicked in the last 0.5 s. Does the label list the slot, or is the duration `0`?

**The `` ` `` key does nothing.** The backtick hotkey is bound to the key left of `1` on a US layout. On other layouts that physical key may produce something else — bind by scan code instead:

```autohotkey
SC029:: {
```

**PoE misses the occasional keypress.** Raise the key delay near the top:

```autohotkey
SetKeyDelay(10, 10)
```

**`Alt+C` / `Alt+M` click the wrong cells.** Coordinates are wrong for your setup — recalibrate with `Alt+H`. If clicks are being dropped rather than misplaced, raise `ClickDelay` from `25`.

**Something errored.** Errors are written to `PoEAutoFlask.log` and flashed as a tooltip, deliberately *without* a modal dialog — a modal over a fullscreen game reads as a freeze, and dismissing it wrongly kills the script. The script keeps running; check the log.

---

## Limitations

- Screen coordinates are **untested** — see [Screen coordinates](#screen-coordinates).
- `Alt+D` under-reads when you have passive/ascendancy flask duration.
- Buff flasks only — not Life, Mana, or Hybrid.
- `` ` `` fires **every** slot in `FlaskOrder`, including ones set to `0`. That is deliberate ("use everything now"), but it means a disabled slot still gets a keypress.
- `Alt+D` handles slots 1–5 only; `e` and `r` are hand-configured.
- No GUI for settings — configuration is the block at the top of the file, plus the INI.

## What changed from v1

Porting notes, the bugs fixed on the way, and what is new relative to the original are in **[CHANGES.md](CHANGES.md)**.

---

## Credits

The original **[PoEAutoFlask](https://github.com/JoelStanford/PoEAutoFlask)** is by **Joel Stanford** ([@JoelStanford](https://github.com/JoelStanford)). The design — timer-tracked flask cycling gated on recent attacks, the inventory and stash sweeps, the gem swap — is his. This repository is a port of that work to AutoHotkey v2, with some additions.

If you find this useful, the credit for the idea belongs upstream.

---

## Support

<a href="https://www.buymeacoffee.com/NGCK"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="48"></a>

Not expected, genuinely appreciated. Bug reports and PRs are worth more.
