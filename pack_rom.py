"""
pack_rom.py - Build a flat ROM image for the HarpMudd Tapper Pocket core.

ROM image layout (0x3A000 bytes = 232 KB; byte offset = dn_addr in FPGA):

  0x00000-0x0DFFF   Z80 main CPU program  (3 x 16 KB + 1 x 8 KB = 56 KB)
                    -> cpu_rom dpram (read by mcr3.cpu_rom_addr/do)
  0x0E000-0x11FFF   Sound CPU program     (4 x 4 KB = 16 KB)
                    -> snd_rom dpram (read by mcr3.snd_rom_addr/do)
  0x12000-0x31FFF   Sprite (foreground) graphics ROMs (8 x 16 KB = 128 KB)
                    -> sprite_rom dpram, 32K x 32-bit
                       (read by mcr3.sp_addr -> sp_graphx32_do[31:0];
                        byte lane = dn_addr[1:0] during load)
  0x32000-0x39FFF   Background tile ROMs (2 x 16 KB = 32 KB)
                    -> mcr3.dl_addr[15:0] = (dn_addr - 0x32000),
                       dl_wr=1 only in this region. mcr3 internal BG BRAM
                       chip-selects on dl_addr[15:14].

Layout matches MiSTer Arcade-MCR3 .mra "Tapper (Budweiser, 840127)" exactly,
so we can drop in the MiSTer rtl/mcr3.vhd unchanged and trust its ROM
indexing.

IMAGE SIZE = 0x3A000 (true end of data). NO zero-padding past this.
PROM/BG chip-selects in mcr3.vhd partially decode dl_addr; padding writes
would alias onto BG ROM #1 (range 0x0000-0x3FFF of dl_addr) and corrupt it.

NOTE on CPU CRCs:
  Targets the 1-27-84 Budweiser set (matches MiSTer Arcade-MCR3 .mra):
    bb060bb0 (1c)  fd9acc22 (2c)  b3755d41 (3c)  77273096 (4c)
  An older revision exists (127171d1/9d6a47f7/3a1f8778/e8dcdaa4) but the
  MiSTer RTL was built/tested against the canonical Budweiser ROMs, so
  we use those.

Usage:
  python pack_rom.py        (builds dist/Assets/tapper/common/tapper.rom)
"""

import sys
import zipfile
import zlib
import os

DEFAULT_ZIP_DIR = r"C:\Projects\Downloaded_Artifacts"
ASSETS_DIR      = r"C:\Projects\HarpMudd.tapper\dist\Assets\tapper\common"

ROM_IMAGE_SIZE = 0x3A000   # 237568 bytes = 232 KB. Do NOT pad past this.

# (CRC32, expected_size, description, rom_image_offset, mirror_offset_or_None)
TAPPER_ROM_DEFS = [
    # --- Z80 main CPU program (mcr3.cpu_rom_addr -> cpu_rom dpram) ---
    # Canonical Budweiser 1-27-84 revision (matches MiSTer Arcade-MCR3 .mra)
    (0xbb060bb0, 0x4000, "tappg0  (Z80 prog 0, 1c)",       0x00000, None),
    (0xfd9acc22, 0x4000, "tappg1  (Z80 prog 1, 2c)",       0x04000, None),
    (0xb3755d41, 0x4000, "tappg2  (Z80 prog 2, 3c)",       0x08000, None),
    (0x77273096, 0x2000, "tappg3  (Z80 prog 3, 4c)",       0x0C000, None),
    # --- SSIO Z80 sound CPU program (mcr3.snd_rom_addr -> snd_rom dpram) ---
    (0x0e8bb9d5, 0x1000, "tapsnda7  (snd 0, a7)",          0x0E000, None),
    (0x0cf0e29b, 0x1000, "tapsnda8  (snd 1, a8)",          0x0F000, None),
    (0x31eb6dc6, 0x1000, "tapsnda9  (snd 2, a9)",          0x10000, None),
    (0x01a9be6a, 0x1000, "tapsda10  (snd 3, a10)",         0x11000, None),
    # --- Sprite/foreground graphics (mcr3.sp_addr[14:0] -> 32-bit word) ---
    # Order matches the .mra; byte lane = dn_addr[1:0] during load.
    (0x32509011, 0x4000, "tapfg1  (sprite fg_1, a7)",      0x12000, None),
    (0x8412c808, 0x4000, "tapfg0  (sprite fg_0, a8)",      0x16000, None),
    (0x818fffd4, 0x4000, "tapfg3  (sprite fg_3, a5)",      0x1A000, None),
    (0x67e37690, 0x4000, "tapfg2  (sprite fg_2, a6)",      0x1E000, None),
    (0x800f7c8a, 0x4000, "tapfg5  (sprite fg_5, a3)",      0x22000, None),
    (0x32674ee6, 0x4000, "tapfg4  (sprite fg_4, a4)",      0x26000, None),
    (0x070b4c81, 0x4000, "tapfg7  (sprite fg_7, a1)",      0x2A000, None),
    (0xa37aef36, 0x4000, "tapfg6  (sprite fg_6, a2)",      0x2E000, None),
    # --- Background tile ROMs (mcr3.dl_addr[15:0] = dn_addr - 0x32000) ---
    (0x2a30238c, 0x4000, "tapbg1  (bg_1, 6f)",             0x32000, None),
    (0x394ab576, 0x4000, "tapbg0  (bg_0, 5f)",             0x36000, None),
]

OUT_NAME = "tapper.rom"
DESC     = "Tapper (Bally Midway, 1983)"


def crc32_of(data):
    return zlib.crc32(data) & 0xFFFFFFFF


def load_zip_by_crc(zip_path):
    found = {}
    with zipfile.ZipFile(zip_path) as zf:
        for info in zf.infolist():
            data = zf.read(info.filename)
            found[crc32_of(data)] = data
    return found


def load_dir_by_crc(zip_dir):
    found = {}
    zips = sorted(f for f in os.listdir(zip_dir) if f.lower().endswith('.zip'))
    if not zips:
        print(f"  (no zip files found in {zip_dir})")
        return found
    for zname in zips:
        print(f"  scanning {zname}")
        try:
            found.update(load_zip_by_crc(os.path.join(zip_dir, zname)))
        except Exception as e:
            print(f"  WARNING: could not read {zname}: {e}")
    return found


def main():
    out_path = os.path.join(ASSETS_DIR, OUT_NAME)

    print(f"ROM packer - {DESC}")
    print(f"Output: {out_path}\n")
    print(f"Scanning all zips in: {DEFAULT_ZIP_DIR}")
    found = load_dir_by_crc(DEFAULT_ZIP_DIR)
    print()

    image = bytearray(ROM_IMAGE_SIZE)
    errors = []

    for (crc, size, desc, offset, mirror) in TAPPER_ROM_DEFS:
        if crc in found:
            data = found[crc]
            if len(data) != size:
                errors.append(f"  WRONG SIZE  {desc}: expected {size}, got {len(data)}")
                continue
            image[offset:offset + size] = data
            if mirror is not None:
                image[mirror:mirror + size] = data
            print(f"  OK          {desc}  @ 0x{offset:05X}")
        else:
            errors.append(f"  MISSING     {desc}  (CRC {crc:08x})")

    print()
    if errors:
        print("MISSING OR INVALID ROMs:")
        for e in errors:
            print(e)
        sys.exit(1)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(image)

    print(f"\nSUCCESS: wrote {len(image)} bytes (0x{len(image):X}) -> {out_path}")


if __name__ == "__main__":
    main()
