# Details! QuickBtnBar

A compact quick-switch button bar for [Details! Damage Meter](https://www.curseforge.com/wow/addons/details). One click switches what your Details! window shows — no more digging through menus mid-fight.

![Interface: Retail](https://img.shields.io/badge/Interface-Retail-blue)

## What it does

QuickBtnBar adds a slim button bar with one button per Details! display ("broker"): DPS, HPS, Damage Done, Damage Taken, Deaths, Interrupts, Dispels, and more.

- **Left-click** a button → the Details! window switches to that display (e.g. *Damage Done*, *Healing Done*, *Deaths*).
- **Right-click** a button → toggles the window between **Current segment** and **Overall** data.
- The active display is highlighted on the bar, including an **(C)**/**(O)** marker for Current/Overall.

Since the bar only *switches* the Details! window (it doesn't read combat values itself), it works everywhere — including instances where Blizzard restricts combat data access for addons.

> **Disclaimer:** This is an unofficial fan-made companion addon. It is **not affiliated with, endorsed by, or supported by** the Details! Damage Meter project or its authors. All credit for Details! itself goes to its developers.

## Features

- **Two modes**
  - **Free mode** – a single movable bar you can place anywhere (unlock, drag, lock).
  - **Docked mode** – one bar attached on top of *each* visible Details! window, automatically following the window's width and position. Each bar controls its own window, so two windows can show e.g. Current DPS and Overall Deaths side by side.
- **Per-window assignment** – choose for every broker on which window bar(s) it appears.
- **Visibility scopes** – show a window's bar always, only in dungeons, only in raids, or in both.
- **Drag & drop reorder** – unlock the bar and drag buttons to rearrange them.
- **Customizable look** – accent color (defaults to your class color), background opacity, vertical offset.
- **Minimap button** – quick access to the settings (can be disabled).
- **Localized** – English and German included; uses your client language by default, manually selectable in the options.

## Available brokers

| Damage | Healing | Misc |
|---|---|---|
| Damage Done | Healing Done | Interrupts |
| DPS | HPS | Dispels |
| Damage Taken | Overhealing | Deaths |
| Enemy Dmg Taken | Potions | |
| Avoidable Dmg | | |

Each broker can be enabled/disabled individually.

## Usage

Open the settings with the minimap button or the slash command:

```
/dqb
```

Additional commands:

| Command | Effect |
|---|---|
| `/dqb lock` | Lock the bar |
| `/dqb unlock` | Unlock the bar (move / reorder) |
| `/dqb reset` | Reset all settings (reloads the UI) |

## Requirements

- [Details! Damage Meter](https://www.curseforge.com/wow/addons/details) (hard dependency)
- World of Warcraft Retail

## Installation

1. Download and unpack into `World of Warcraft\_retail_\Interface\AddOns\`, or install via the CurseForge app.
2. Make sure Details! is installed and enabled.
3. Log in and type `/dqb`.

## FAQ

**The bar doesn't show any numbers — is that intended?**
Yes. In instanced content Blizzard blocks combat-value access for addons, so the bar is deliberately a pure *switcher* for Details! rather than a second meter.

**Where is the bar after installation?**
In free mode it appears centered above the middle of your screen. Use `/dqb unlock` to move it, or enable *Anchor to Details* to dock it to your Details! windows.

**Does it support more than one Details! window?**
Yes, up to four. In docked mode every visible window gets its own bar.

## License

MIT — see [LICENSE](LICENSE).
