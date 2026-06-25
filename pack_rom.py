"""
pack_rom.py - Build flat ROM images for the HarpMudd Tapper Pocket core.

Multi-edition. One bitstream runs every Tapper edition (all MCR mod=0, identical
hardware; they differ only in ROM content), so it's a pure ROM-recipe swap - no
variant byte needed.

ROM image layout (0x3A000 bytes = 232 KB; byte offset = dn_addr in the FPGA).
Mirrors the MiSTer Arcade-MCR3 .mra layout, so mcr3.vhd indexes it unchanged:
  0x00000-0x0DFFF  Z80 main CPU program   56 KB  (3x16K + 1x8K)
  0x0E000-0x11FFF  Sound CPU program      16 KB  (4x4K)
  0x12000-0x31FFF  Sprite (fg) graphics  128 KB  (8x16K)
  0x32000-0x39FFF  Background tile ROMs   32 KB  (2x16K)
IMAGE SIZE = 0x3A000 (true end of data). NO zero-padding past this - mcr3.vhd
partially decodes dl_addr, so padding would alias onto BG ROM #1 and corrupt it.

Matching is purely by CRC32, so the (often cryptic) filenames inside the MAME
zips do not matter; split clones resolve shared ROMs from the parent tapper.zip.

Usage:
  python pack_rom.py [edition]   # tapper tapperg tappera tapperb sutapper rbtapper
  python pack_rom.py all         # build every edition
"""

import sys
import zipfile
import zlib
import os

DEFAULT_ZIP_DIR = r"C:\Projects\Downloaded_Artifacts"
ASSETS_DIR      = r"C:\Projects\HarpMudd.tapper\dist\Assets\tapper\common"

# Variant byte at 0x3A000 selects the MiSTer Arcade-MCR3 `mod` in core_top.v:
#   0 = Tapper (all editions, mod=0)   1 = Timber (mod=1, 2-button/2-player inputs)
# The byte sits PAST the 0x3A000 data end (image padded to 0x3A200). core_top
# snoops it; the cpu/snd/sprite/bg region forwards to mcr3 are all gated to
# dn_addr < 0x3A000, so it never reaches mcr3's dl_addr demux (no aliasing).
VARIANT_OFFSET  = 0x3A000
ROM_IMAGE_SIZE  = 0x3A200
VARIANTS        = {"timber": 1}   # default 0 (Tapper editions)

# Fixed region offsets/sizes (same for every edition). Each edition supplies its
# four ROM-CRC lists in MAME ROM_START order; they drop into these slots.
CPU_OFF = [(0x00000, 0x4000), (0x04000, 0x4000), (0x08000, 0x4000), (0x0C000, 0x2000)]
SND_OFF = [(0x0E000, 0x1000), (0x0F000, 0x1000), (0x10000, 0x1000), (0x11000, 0x1000)]
SPR_OFF = [(0x12000, 0x4000), (0x16000, 0x4000), (0x1A000, 0x4000), (0x1E000, 0x4000),
           (0x22000, 0x4000), (0x26000, 0x4000), (0x2A000, 0x4000), (0x2E000, 0x4000)]
BG_OFF  = [(0x32000, 0x4000), (0x36000, 0x4000)]

# Per edition: (description, cpu[4], snd[4], sprite[8], bg[2])  -- all CRC32s.
GAMES = {
    "tapper": ("Tapper (Budweiser, 1/27/84)",
        [0xbb060bb0, 0xfd9acc22, 0xb3755d41, 0x77273096],
        [0x0e8bb9d5, 0x0cf0e29b, 0x31eb6dc6, 0x01a9be6a],
        [0x32509011, 0x8412c808, 0x818fffd4, 0x67e37690, 0x800f7c8a, 0x32674ee6, 0x070b4c81, 0xa37aef36],
        [0x2a30238c, 0x394ab576]),

    "rbtapper": ("Tapper (Root Beer)",
        [0x20b9adf4, 0x87e616c2, 0x0b332c97, 0x698c06f2],
        [0x5c1d0982, 0x09e74ed8, 0xc3e98284, 0xced2fd47],
        [0x1c0b8791, 0xe99f6018, 0x3e725e77, 0x4ee8b624, 0x9eeca46e, 0x8c79e7d7, 0x8dbf0c36, 0x441201a0],
        [0x44dfa483, 0x510b13de]),

    "sutapper": ("Tapper (Suntory)",
        [0x87119cc4, 0x4c23ad89, 0xfecbf683, 0x5bdc1916],
        [0x5c1d0982, 0x09e74ed8, 0xc3e98284, 0xced2fd47],
        [0x5d987c92, 0xde5700b4, 0xf10a1d05, 0x614990cd, 0x02c69432, 0xebf1f948, 0xd70defa7, 0xd4f114b9],
        [0xac1558c1, 0xfa66cab5]),

    "tapperg": ("Tapper (Budweiser, 1/27/84 - alternate graphics)",
        [0xbb060bb0, 0xfd9acc22, 0xb3755d41, 0x77273096],
        [0x0e8bb9d5, 0x0cf0e29b, 0x31eb6dc6, 0x01a9be6a],
        [0xbac70b69, 0xc300925d, 0xecff6c23, 0xa4f2d1be, 0x16ce38cb, 0x082a4059, 0x3b476abe, 0x6717264c],
        [0x2a30238c, 0x394ab576]),

    "tappera": ("Tapper (Budweiser, 1/12/84)",
        [0x127171d1, 0x9d6a47f7, 0x3a1f8778, 0xe8dcdaa4],
        [0x0e8bb9d5, 0x0cf0e29b, 0x31eb6dc6, 0x01a9be6a],
        [0x32509011, 0x8412c808, 0x818fffd4, 0x67e37690, 0x800f7c8a, 0x32674ee6, 0x070b4c81, 0xa37aef36],
        [0x2a30238c, 0x394ab576]),

    "tapperb": ("Tapper (Budweiser, 12/9/83)",
        [0x496a8e04, 0xe79c4b0c, 0x3034ccf0, 0x2dc99e05],
        [0x0e8bb9d5, 0x0cf0e29b, 0x31eb6dc6, 0x01a9be6a],
        [0x32509011, 0x8412c808, 0x818fffd4, 0x67e37690, 0x800f7c8a, 0x32674ee6, 0x070b4c81, 0xa37aef36],
        [0x2a30238c, 0x394ab576]),

    # Timber - same 91490 board, MCR mod=1 (only 3 sound ROMs). variant byte = 1.
    "timber": ("Timber",
        [0x377032ab, 0xfd772836, 0x632989f9, 0xdae8a0dc],
        [0xc615dc3e, 0x83841c87, 0x22bcdcd3],
        [0x81de4a73, 0x7f3a4f59, 0x37c03272, 0xe2c2885c, 0xeb636216, 0xb7105eb7, 0xd9c27475, 0x244778e8],
        [0xb1cb2651, 0x2ae352c4]),
}


def crc32_of(data):
    return zlib.crc32(data) & 0xFFFFFFFF


def load_dir_by_crc(zip_dir):
    found = {}
    for zname in sorted(f for f in os.listdir(zip_dir) if f.lower().endswith('.zip')):
        try:
            with zipfile.ZipFile(os.path.join(zip_dir, zname)) as zf:
                for info in zf.infolist():
                    data = zf.read(info.filename)
                    found[crc32_of(data)] = data
        except Exception as e:
            print(f"  WARNING: could not read {zname}: {e}")
    return found


def build(game, found):
    desc, cpu, snd, spr, bg = GAMES[game]
    out_path = os.path.join(ASSETS_DIR, game + ".rom")
    print(f"\n=== {desc} -> {game}.rom ===")

    image = bytearray(ROM_IMAGE_SIZE)
    errors = []
    plan = list(zip(cpu, CPU_OFF)) + list(zip(snd, SND_OFF)) + \
           list(zip(spr, SPR_OFF)) + list(zip(bg, BG_OFF))
    for crc, (offset, size) in plan:
        if crc in found:
            data = found[crc]
            if len(data) != size:
                errors.append(f"  WRONG SIZE  {crc:08x}: expected {size}, got {len(data)}")
                continue
            image[offset:offset + size] = data
        else:
            errors.append(f"  MISSING     CRC {crc:08x}")

    if errors:
        print("  -- MISSING/INVALID:")
        for e in errors:
            print(e)
        return False
    image[VARIANT_OFFSET] = VARIANTS.get(game, 0)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(image)
    print(f"  SUCCESS: {len(image)} bytes (0x{len(image):X}, variant {VARIANTS.get(game, 0)})")
    return True


def main():
    arg = (sys.argv[1].lower() if len(sys.argv) > 1 else "tapper")
    targets = list(GAMES) if arg == "all" else [arg]
    for t in targets:
        if t not in GAMES:
            print(f"ERROR: unknown edition '{t}'. Choose: {', '.join(GAMES)}, or 'all'")
            sys.exit(1)
    print(f"Scanning zips in: {DEFAULT_ZIP_DIR}")
    found = load_dir_by_crc(DEFAULT_ZIP_DIR)
    ok = all(build(t, found) for t in targets)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
