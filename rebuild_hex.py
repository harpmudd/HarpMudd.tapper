"""Regenerate cpu_rom.hex / snd_rom.hex / sprite_b*.hex from tapper.rom.

The .hex files are used by $readmemh in the FPGA RTL to pre-init BRAMs.
Run AFTER pack_rom.py rebuilds tapper.rom.
"""
import os

ROM_PATH = r"C:\Projects\HarpMudd.tapper\dist\Assets\tapper\common\tapper.rom"
HEX_DIR  = r"C:\Projects\HarpMudd.tapper\src\fpga"

def write_hex(path, data):
    with open(path, "w") as f:
        for b in data:
            f.write(f"{b:02X}\n")
    print(f"  wrote {path}  ({len(data)} bytes)")

def main():
    with open(ROM_PATH, "rb") as f:
        rom = f.read()
    print(f"loaded {ROM_PATH}: {len(rom)} bytes")

    # CPU ROM: 56 KB starting at 0x00000, padded to 64 KB
    cpu_rom = bytearray(rom[0x00000:0x0E000])
    cpu_rom += bytes(0x10000 - len(cpu_rom))
    write_hex(os.path.join(HEX_DIR, "cpu_rom.hex"), cpu_rom)

    # Sound ROM: 16 KB starting at 0x0E000
    snd_rom = rom[0x0E000:0x12000]
    write_hex(os.path.join(HEX_DIR, "snd_rom.hex"), snd_rom)

    # Sprite ROM: 128 KB starting at 0x12000, split into 4 contiguous 32 KB lanes.
    # MiSTer's SDRAM remap {sp_ioctl_addr[18:17], sp_ioctl_addr[14:0], sp_ioctl_addr[16]}
    # ends up putting each lane as a contiguous 32 KB chunk of the sprite section:
    #   Lane 0 = sp_section[0x00000:0x08000]  (tapfg1 + tapfg0)
    #   Lane 1 = sp_section[0x08000:0x10000]  (tapfg3 + tapfg2)
    #   Lane 2 = sp_section[0x10000:0x18000]  (tapfg5 + tapfg4)
    #   Lane 3 = sp_section[0x18000:0x20000]  (tapfg7 + tapfg6)
    sp_section = rom[0x12000:0x32000]   # 128 KB
    for lane in range(4):
        lane_bytes = sp_section[lane * 0x8000 : (lane + 1) * 0x8000]
        write_hex(os.path.join(HEX_DIR, f"sprite_b{lane}.hex"), lane_bytes)

    print("done")

if __name__ == "__main__":
    main()
