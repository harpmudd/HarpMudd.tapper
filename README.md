# Tapper — Analogue Pocket

An Analogue Pocket port of **Tapper** (Bally Midway, 1983) by **HarpMudd**, built
on the openFPGA framework.

## The Game

Last call, and the bar is packed. Work four counters at once, sliding frosty mugs
down the line to a never-ending crowd of thirsty patrons — then catch the empties
they slide back before they smash. Scoop up tips, keep every customer from
reaching the end of the bar, and survive the rush across saloon, sports bar, punk
bar and space bar. A frantic, beloved test of timing and nerve.

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
