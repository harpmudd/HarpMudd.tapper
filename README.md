# Tapper — Analogue Pocket

An Analogue Pocket port of **Tapper** (Bally Midway, 1983) by **HarpMudd**, built
on the openFPGA framework. One core, every edition — selectable from the Pocket
library:

- **Tapper** — Budweiser, 1/27/84 (the classic)
- **Tapper (Root Beer)** — the soda re-theme
- **Tapper (Suntory)** — the Japanese release
- **Tapper (Alternate Graphics)** and the **1/12/84** and **12/9/83** revisions
- **Timber** — Bally Midway's lumberjack game on the same board

Tapper and Timber are the same MCR hardware; a variant byte in each ROM image
tells the core which input layout to use (Timber adds a second action button and
second player).

## The Game

Last call, and the bar is packed. Work four counters at once, sliding frosty mugs
down the line to a never-ending crowd of thirsty patrons — then catch the empties
they slide back before they smash. Scoop up tips, keep every customer from
reaching the end of the bar, and survive the rush across saloon, sports bar, punk
bar and space bar. A frantic, beloved test of timing and nerve.

All editions are the same MCR hardware — they differ only in ROMs, so one
bitstream runs them all.

## Hardware

Tapper runs on Bally Midway's **MCR3** board:

| Part | Role |
|---|---|
| Zilog Z80 | Main CPU |
| Zilog Z80 (SSIO board) | Sound, driving dual AY-3-8910 PSGs |
| Display | Horizontal CRT, 15 kHz, RGB |

## The Port

Built on the MiSTer **Arcade-MCR3** core:

- **MiSTer port:** Sorgelig (2019)
- **FPGA arcade hardware implementation:** Dar — [darfpga](https://darfpga.blogspot.fr) (darfpga@aol.fr)

This Analogue Pocket build adapts that RTL to the openFPGA / APF framework. Many
thanks to Sorgelig and Dar.

## Controls

| Pocket | Action |
|---|---|
| **D-Pad** | Move between / along the bars |
| **A** | Pour / serve & collect mugs |
| **Start** | 1P Start |
| **Select** | Insert coin |

## Using It

Copy `Cores/`, `Assets/` and `Platforms/` to your Pocket's SD card. Each edition
is a small instance JSON in `Assets/tapper/HarpMudd.tapper/`; launch the core and
you drop straight into that folder to pick one, or browse to it from the Pocket
library. The selected edition is loaded by its `.json`.

## ROMs

ROMs are **not** included — nothing in this repo contains copyrighted data.
Supply your own MAME romsets (`tapper`, `rbtapper`, `sutapper`, `tapperg`,
`tappera`, `tapperb`, `timber`) and build the per-game `.rom` images with
`pack_rom.py` into `Assets/tapper/common/`. `pack_rom.py` matches the required
files by CRC32, so it only assembles the correct, verified dumps.

## Credits

- **Original arcade game:** Bally Midway (1983)
- **MiSTer Arcade-MCR3 port:** Sorgelig
- **FPGA arcade core:** Dar (darfpga)
- **Analogue Pocket port:** HarpMudd

## About / Support

I'm into retro games and the Analogue Pocket, always cooking up something new.
I love being part of a community built on sharing and the love of games — so if
any of my projects bring you joy, grab me a coffee; it fuels the next thing.

☕ **[buymeacoffee.com/harpmudd](https://buymeacoffee.com/harpmudd)**
