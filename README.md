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
  - [Silent Assassin (fork)](#4-silent-assassin-fork)
- [Notes](#notes)
- [License](#license)

## Install

1. Install **[SuperBLT](https://superblt.znix.xyz/)** if you do not already have it.  
2. Copy each mod **folder** into:

   `…\Steam\steamapps\common\PAYDAY 2\mods\`

3. Full restart PAYDAY 2.  
4. Configure under **Options → Mod Options**.

## Mods

### 1) Big Ammo Pickups

Buffs ammo from the small boxes enemies drop.

- Multiplier (default **10×**)
- Optional min/max floors
- Optional boost for zero-pickup weapons (RPG, saw, bows, etc.)
- Fully Loaded / Walk-in Closet still stack on top

### 2) Omniscience+

Buffs **Sixth Sense** stealth radar (stand-still).

- Faster sense delay, longer range
- Marks guards (and optional cameras / items) with real contours
- Local-only by default; optional team sync
- Independent of VanillaHUD’s sense hooks where possible

### 3) Saw Stealth Conceal

Raises **OVE9000 Saw** concealment for stealth builds (default **30**).

- Slider in Mod Options  
- Primary + secondary saw tweak entries  

### 4) Silent Assassin (fork)

Based on **Silent Assassin** by **DrTachyon** (pager / stealth-kill rules).

**Luckysugar additions** (defaults **on**):

| Option | Effect |
|--------|--------|
| **Only My Kills** | No-pager stealth kill applies only to **your** kills (best when you host) |
| **Only While Crouching** | No-pager only if the killer is **crouching** |

Original SA options (pager counts, detection threshold, matchmaking filter) still work.

> Host authority: pager removal is decided on the **server**. Host this mod for reliable behavior.

## Notes

- These are **mods**, not cheats aimed at public matchmaking advantage. Use common sense online.  
- Silent Assassin updates from the original author may overwrite a Vortex install — keep this fork folder if you want the crouch / local options.  
- Game Lua dumps for research: [Payday-2-LuaJIT-Complete](https://github.com/steam-test1/Payday-2-LuaJIT-Complete) (reference only).

## License

MIT for **original Luckisugar code** (Big Ammo, Omniscience+, Saw Stealth Conceal).

Silent Assassin remains credit to **DrTachyon**; this repo ships a small fork with extra options. If the original license differs, treat that folder under the original author’s terms and contact them for redistribution questions.
