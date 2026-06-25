"""
package.py - Package the compiled Tapper core for the Analogue Pocket.

The distribution layout lives at the REPO ROOT (Cores/ Assets/ Platforms/) so
the repo top-level mirrors the Pocket SD card. The romset is kept on local disk
under Assets/tapper/common/ but is git-ignored (copyrighted, never pushed).

Steps:
  1. Verify the bitstream exists in src/fpga/output_files/
  2. Convert .rbf -> .rbf_r (byte-reversed bitstream for Pocket)
  3. Copy bitstream to Cores/HarpMudd.tapper/bitstream.rbf_r
  4. Run pack_rom.py to generate tapper.rom (if not already present)
  5. Print copy instructions for the Pocket SD card

Usage:
  python package.py [--skip-rom]
"""

import os
import sys
import shutil
import struct
import subprocess

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
DIST_ROOT     = os.path.join(PROJECT_ROOT, "dist")
BITSTREAM_SRC = os.path.join(PROJECT_ROOT, "src", "fpga", "output_files", "ap_core.rbf")
CORE_DST      = os.path.join(DIST_ROOT, "Cores", "HarpMudd.tapper")
BITSTREAM_DST = os.path.join(CORE_DST, "bitstream.rbf_r")
ROM_DST       = os.path.join(DIST_ROOT, "Assets", "tapper", "common", "tapper.rom")
PACK_ROM_PY   = os.path.join(PROJECT_ROOT, "pack_rom.py")
SD_DIRS       = ("Cores", "Assets", "Platforms")


def rbf_to_rbf_r(src, dst):
    """Reverse the bit order of each byte in the .rbf (Pocket requires bit-reversed bitstream)."""
    with open(src, "rb") as f:
        data = f.read()

    rev = bytearray(len(data))
    for i, b in enumerate(data):
        rev[i] = int(f"{b:08b}"[::-1], 2)

    with open(dst, "wb") as f:
        f.write(bytes(rev))

    print(f"  bitstream: {src}")
    print(f"  -> rbf_r : {dst}  ({len(rev)} bytes)")


def main():
    skip_rom = "--skip-rom" in sys.argv

    print("=== Tapper Pocket Core Packager ===\n")

    # 1. Bitstream
    if not os.path.exists(BITSTREAM_SRC):
        print(f"ERROR: bitstream not found: {BITSTREAM_SRC}")
        print("Run Quartus compilation first:")
        print(f"  quartus_sh --flow compile {os.path.join(PROJECT_ROOT, 'src', 'fpga', 'ap_core.qpf')}")
        sys.exit(1)

    os.makedirs(CORE_DST, exist_ok=True)
    print("Converting bitstream...")
    rbf_to_rbf_r(BITSTREAM_SRC, BITSTREAM_DST)

    # 2. ROM
    if not skip_rom:
        if os.path.exists(ROM_DST):
            print(f"\nROM already exists: {ROM_DST}")
        else:
            print("\nBuilding ROM image...")
            result = subprocess.run([sys.executable, PACK_ROM_PY], capture_output=False)
            if result.returncode != 0:
                print("\nROM build failed. Package incomplete.")
                print("Provide a complete MAME pacman.zip and re-run.")
                sys.exit(1)

    # 3. Summary  (the distribution lives under dist/: Cores/ Assets/ Platforms/)
    print("\n=== Package contents (dist/) ===")
    for top in SD_DIRS:
        top_path = os.path.join(DIST_ROOT, top)
        if not os.path.isdir(top_path):
            continue
        for root, dirs, files in os.walk(top_path):
            dirs.sort()
            level = root.replace(DIST_ROOT, "").count(os.sep) - 1
            indent = "  " * level
            print(f"{indent}{os.path.basename(root)}/")
            for f in sorted(files):
                size = os.path.getsize(os.path.join(root, f))
                print(f"{indent}  {f}  ({size:,} bytes)")

    print("\n=== Copy to Pocket SD card ===")
    print("Copy the contents of dist/ to the root of your Pocket SD card:")
    for top in SD_DIRS:
        print(f"  xcopy /E /Y \"{os.path.join(DIST_ROOT, top)}\" X:\\{top}\\")
    print("(replace X: with your Pocket SD card drive letter)")


if __name__ == "__main__":
    main()
