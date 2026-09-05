# Payday 2 Mods (Luckisugar)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Game](https://img.shields.io/badge/game-PAYDAY%202-yellow)](#)
[![Loader](https://img.shields.io/badge/loader-SuperBLT-orange)](#)

Personal SuperBLT mods for **PAYDAY 2**. Client-side QoL / stealth tooling. Not affiliated with Starbreeze or Overkill.

---

## Table of contents

- [Install](#install)
- [Mods](#mods)
  - [Big Ammo Pickups](#1-big-ammo-pickups)
  - [Omniscience+](#2-omniscience)
  - [Saw Stealth Conceal](#3-saw-stealth-conceal)
  - [Ninja](#4-ninja)
  - [Auto Skill Sets](#5-auto-skill-sets)
  - [Instant Heists](#6-instant-heists)
  - [Loot Mule](#7-loot-mule)
  - [Instant Restart](#8-instant-restart)
  - [Ally Spectate](#9-ally-spectate)
  - [Diamond Path Helper](#10-diamond-path-helper)
  - [Meth Helper](#11-meth-helper)
  - [You and What Army](#12-you-and-what-army)
- [License](#license)

## Install

1. Install **[SuperBLT](https://superblt.znix.xyz/)** (64-bit / Diesel 3.0).  
2. Copy **`HeistHelper`** (the hub) plus any **`HH_*`** module folders into:

   `…\Steam\steamapps\common\PAYDAY 2\mods\`

   Nexus zips already contain both. Installing a second pack only adds another `HH_*` folder; overwriting `HeistHelper` is safe.

3. Full restart PAYDAY 2.  
4. Configure under **Options → Mod Options → Heist Helper**.

## Mods

### 1) Big Ammo Pickups

Buffs ammo from the small boxes enemies drop.

### 2) Omniscience+

Buffs **Sixth Sense** stealth radar (stand still to pulse).

### 3) Saw Stealth Conceal

Raises **OVE9000 Saw** concealment for stealth builds (default **30**).

### 4) Ninja

Based on **Silent Assassin** by **DrTachyon** (pager / stealth-kill rules).

### 5) Auto Skill Sets

Saves skill builds and re-spends them after **infamy** / level-ups so you are not rebuilding the same tree by hand every time. **Edit (Cheat)** also covers extra-point skill sets, skill budget sliders, and masking outfit totals.

> Cheat restore / Edit (Cheat) can trip skill-point detectors and look bad online. Use at your own risk.

### 6) Instant Heists

Full **cheat** mod: skip equipment gates and speed up waits.

> Host for reliable mission timers. Pure client-only lobbies will not always speed host-side scripts. This is an obvious cheat — expect desync / lobby drama online.

### 7) Loot Mule

Carry **as many bags as you want** (stack, last in / first out). Not Carry Stacker — original Luckysugar mod. Per-class throw distance and stash (no weight) live under Heist Helper.

### 8) Instant Restart

**Host hotkey** to restart the current heist, **rebuy last preplan + mission assets**, and **auto-start past briefing** into map load.
> Host only. Blocked while a peer is still loading (reduces blackscreens).

### 9) Ally Spectate

Live **through-their-eyes** camera on your teammates while you are still alive.
> Other players are third-person husks on your client, so this tracks **head position + look direction** (not their exact FPS hands).

### 10) Diamond Path Helper

Prints the **real** safe floor-tile path for **The Diamond** after the chamber path box is hacked (not the buggy light guide).
> Also adds extra 15 seconds to the total timer as in Death Sentence difficulty, the path only lasts for 30s, and the 'showing' of the path takes 15s, so you had 15s to go forth and back.

**v1.3.0:** +15s path timer; numbered `--`/`##` grid; no S/E/D markers.

### 11) Meth Helper

Bain/Locke cook lines as ingredient callouts. Based on **Meth Helper Updated** (Offyerrocker).

### 12) You and What Army

Raise **your** Joker convert cap (vanilla **1**, or **2** with Confident Aced). Slider **2–32**, default **8**. Still needs Joker. Host / solo only. Optional one-yell cuff, insta-convert, no shout delay, and lobby yells.

> If you join someone else, their lobby still enforces 1–2. Teammates in *your* lobby keep their own vanilla cap.

## License

MIT for **original Luckisugar code** (Heist Helper hub, Big Ammo, Omniscience+, Saw Stealth Conceal, Auto Skill Sets, Instant Heists, Loot Mule, Instant Restart, Ally Spectate, Diamond Path Helper, You and What Army).

Ninja remains credit to **DrTachyon** (Silent Assassin fork) with Luckysugar options. Meth Helper cook lines credit **Offyerrocker**. If an original license differs, treat that folder under the original author’s terms.
