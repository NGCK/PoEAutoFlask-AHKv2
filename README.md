# PoEAutoFlask — AutoHotkey **v2**

Automatic buff-flask uptime for Path of Exile.

![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2.0%2B-334455?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows-0078D6?style=flat-square)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-NGCK-FFDD00?style=flat-square&logo=buymeacoffee&logoColor=black)](https://www.buymeacoffee.com/NGCK)

If this saved you some finger pain, you can [buy me a coffee](https://www.buymeacoffee.com/NGCK) ☕

---

An **AutoHotkey v2** port of [JoelStanford/PoEAutoFlask](https://github.com/JoelStanford/PoEAutoFlask), which is v1-only and won't load on v2.

It keeps your buff flasks up while you're fighting — if you've attacked in the last half second, it re-presses any flask whose effect has expired. Standing around in town, it does nothing.

## Requirements

- Windows
- [AutoHotkey v2.0](https://www.autohotkey.com/) or newer

## Install

```bash
git clone https://github.com/NGCK/PoEAutoFlask-AHKv2.git
```

Or just download `PoEAutoFlask_v2.ahk` — one file, no dependencies. Double-click to run. It starts disarmed.

## Quick start

1. In-game, open your inventory, hover flask 1, press **`Alt+D`**. Repeat for flasks 2–5.
2. Press **`Alt+F12`** to arm. A label appears top-left showing which slots are live.
3. Fight.
4. **`Alt+F12`** again to disarm.

Step 1 is once-only — durations are saved and persist.

## Hotkeys

Live only while Path of Exile is the focused window, except `Ctrl+Alt+R`.

| Key | Does |
|---|---|
| `Alt+F12` | Arm / disarm |
| `` ` `` | Use every flask and buff now |
| `1`–`5` | Normal flask use, timer tracked so auto-cycling stays in sync |
| `e` / `r` | Same, for buff skills |
| Right mouse | Your attack — passed through, only watched to know when you're fighting |
| `Alt+D` | Learn the hovered flask's duration and save it |
| `Alt+G` | Copy the mouse's screen coordinates |
| `Alt+H` | Two-point grid calibration |
| `Alt+C` | Ctrl-click every inventory cell |
| `Alt+M` | Move items from a stash tab to inventory |
| `Alt+S` | Swap a skill gem with an alternate |
| `Ctrl+Alt+R` | Reload after editing the file |

## Flask durations

`Alt+D` reads the duration off the hovered flask and saves it to `PoEAutoFlask.ini`. Five presses covers your whole flask bar.

The `5000` ms values shipped in the file are placeholders, not measurements — use `Alt+D`. To set them by hand instead, edit `FlaskDurationInit` at the top of the script; `0` disables a slot. The INI overrides the file, so delete it if you'd rather hand-edit.

Utility flasks only, not Life/Mana/Hybrid. `Alt+D` covers slots 1–5; `e` and `r` are skills, so set those by hand.

## Screen coordinates

Only `Alt+C`, `Alt+M`, and `Alt+S` use coordinates — flask automation doesn't, and works at any resolution.

The shipped values are the original's 2560×1440 numbers ×1.5 for 4K, and are unverified. Fix them with **`Alt+G`** (hover a point, it copies the coords) or **`Alt+H`** (hover the top-left cell, then the cell one right and one down — it works out the origin and cell step).

| Setting | Controls |
|---|---|
| `InvX` / `InvY` / `InvDelta` | Inventory grid (`Alt+C`) |
| `StashY` / `StashD` / `StashSize` | Stash tabs — 1 is 12×12, 2 is 24×24 Quad (`Alt+M`) |
| `PrimX` / `PrimY` / `AltX` / `AltY` | Gem sockets (`Alt+S`) |
| `StatusX` / `StatusY` | Where the armed label sits |

For `Alt+M`, hover the first stash cell *then* press the hotkey — the start position is captured at that moment, so you can click OK with the mouse.

## Files

Written next to the script, both gitignored:

- `PoEAutoFlask.ini` — learned durations
- `PoEAutoFlask.log` — errors, and the item text from every `Alt+D`

## What changed from v1

See [CHANGES.md](CHANGES.md).

## Credits

The original **[PoEAutoFlask](https://github.com/JoelStanford/PoEAutoFlask)** is by **Joel Stanford** ([@JoelStanford](https://github.com/JoelStanford)) — the design is his. This is a port of that work to AutoHotkey v2, with some additions.

## Support

<a href="https://www.buymeacoffee.com/NGCK"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="48"></a>
