# Full disk encryption unlocked by TPM on Trixie

## Introduction

I've just received my Framework Laptop 12.
As all my computers for 15 years, I've installed Debian on it, that's trixie today.
Great surprise, it works out of the box, even the screen rotation doesn't need the fix documented for Ubuntu 25.04!

So, I've followed the installer and chosen Full Disk Encryption but I don't want to type in my passphrase at each boot.
What I want, is having my computer locked with my account password and be sure nobody can bypass the login (for instance by adding `single` in the kernel command line at grub step).
This is where `systemd-cryptsetup` can help: it can register a LUKS key slot tied to the boot sequence thanks to the TPM. The disk will be unlocked if and only if the boot sequence hasn't been tampered with.

We'll use:
* `systemd-cryptenroll` to enroll the TPM ;
* `dracut` to generate an initramfs which uses `systemd-cryptsetup` instead of Debian default's `cryptsetup` ;
* `ukify` to embed  kernel, initramfs and command line into a single signed file ;
* `systemd-boot` to load the UKI.

Since you don't like to break the boot sequence and have to use a rescue disk, we'll do it step by step.

## Migrate to systemd-boot

Even though Trixie installer has support for `systemd-boot` in expert mode, I did not remember when I did the install and `grub` got installed.
Let's start with that.

```shell
sudo apt install systemd-boot
```

Let's check with `efibootmgr` whether it's correctly installed as a bootloader.

```
BootCurrent: 0003
Timeout: 0 seconds
BootOrder: 0005,0003,0000,2001,2002,2003
Boot0000* GRUB Boot Loader	HD(1,GPT,aa227fda-65b7-4e53-8359-5d8bb60925b1,0x800,0x1e8000)/File(\EFI\Boot\grubx64.efi)RC
Boot0001* Windows Boot Manager	HD(2,GPT,948ff571-d613-4398-ba60-195740bc1695,0xa00800,0x82000)/File(\EFI\Microsoft\Boot\bootmgfw.efi)RC
Boot0002* EFI PXE 0 for IPv4 (3C-18-A0-5A-2F-36) 	PciRoot(0x0)/Pci(0xd,0x0)/USB(3,0)/MAC(3c18a05a2f36,0)/IPv4(0.0.0.00.0.0.0,0,0)RC
Boot0003* debian	HD(1,GPT,aa227fda-65b7-4e53-8359-5d8bb60925b1,0x800,0x1e8000)/File(\EFI\debian\shimx64.efi)
Boot0004* Windows Boot Manager	HD(2,GPT,948ff571-d613-4398-ba60-195740bc1695,0xa00800,0x82000)/File(\EFI\Microsoft\Boot\bootmgfw.efi)57494e444f5753000100000088000000780000004200430044004f0042004a004500430054003d007b00390064006500610038003600320063002d0035006300640064002d0034006500370030002d0061006300630031002d006600330032006200330034003400640034003700390035007d00000000000100000010000000040000007fff0400
Boot0005* Linux Boot Manager	HD(1,GPT,aa227fda-65b7-4e53-8359-5d8bb60925b1,0x800,0x1e8000)/File(\EFI\systemd\systemd-bootx64.efi)
Boot2001* EFI USB Device	RC
Boot2002* EFI DVD/CDROM	RC
Boot2003* EFI Network	RC
```

It is installed directly (`Boot0005`) but since it is not chained after `shim`, it won't load with SecureBoot enabled.
`grub` is also installed directly (`Boot0000`) but the current boot is `shim` (`Boot0003`), `shim` is hardcoded to chainload `grub` by default. Luckily, we can give it another path to chainload.
`systemd-boot`'s postinst script is very conservative regarding shim. Let's peek into `/var/lib/dpkg/info/systemd-boot.postinst` to find the right command.

```
# [...]
esp_path="$(bootctl --quiet --print-esp-path 2>/dev/null)"
# [...]
blkpart="$(findmnt -nvo SOURCE "$esp_path")"
if [ ! -L "/sys/class/block/${blkpart##*/}" ]; then
    return
fi
drive="$(readlink -f "/sys/class/block/${blkpart##*/}")"
drive="${drive%/*}"
drive="/dev/${drive##*/}"
partno="$(cat "/sys/class/block/${blkpart##*/}/partition")"
efibootmgr -q --create --disk "$drive" --part "$partno" --loader "EFI/${vendor}/shim${efi_arch}.efi" --label "${vendor_upper}" --unicode "\EFI\systemd\systemd-boot${efi_arch}.efi \0"
# [...]
```

For my laptop, this becomes:

```
sudo efibootmgr -q --create --disk "/dev/nvme0n1" --part "1" --loader "EFI/debian/shimx64.efi" --label "Debian" --unicode "\EFI\systemd\systemd-bootx64.efi \0"
```

The output of `efibootmgr` now gives:
```
BootCurrent: 0003
Timeout: 0 seconds
BootOrder: 0006,0005,0003,0000,2001,2002,2003
Boot0000* GRUB Boot Loader	HD(1,GPT,aa227fda-65b7-4e53-8359-5d8bb60925b1,0x800,0x1e8000)/File(\EFI\Boot\grubx64.efi)RC
Boot0001* Windows Boot Manager	HD(2,GPT,948ff571-d613-4398-ba60-195740bc1695,0xa00800,0x82000)/File(\EFI\Microsoft\Boot\bootmgfw.efi)RC
Boot0002* EFI PXE 0 for IPv4 (3C-18-A0-5A-2F-36) 	PciRoot(0x0)/Pci(0xd,0x0)/USB(3,0)/MAC(3c18a05a2f36,0)/IPv4(0.0.0.00.0.0.0,0,0)RC
Boot0003* debian	HD(1,GPT,aa227fda-65b7-4e53-8359-5d8bb60925b1,0x800,0x1e8000)/File(\EFI\debian\shimx64.efi)
Boot0004* Windows Boot Manager	HD(2,GPT,948ff571-d613-4398-ba60-195740bc1695,0xa00800,0x82000)/File(\EFI\Microsoft\Boot\bootmgfw.efi)57494e444f5753000100000088000000780000004200430044004f0042004a004500430054003d007b00390064006500610038003600320063002d0035006300640064002d0034006500370030002d0061006300630031002d006600330032006200330034003400640034003700390035007d00000000000100000010000000040000007fff0400
Boot0005* Linux Boot Manager	HD(1,GPT,aa227fda-65b7-4e53-8359-5d8bb60925b1,0x800,0x1e8000)/File(\EFI\systemd\systemd-bootx64.efi)
Boot0006* Debian	HD(1,GPT,aa227fda-65b7-4e53-8359-5d8bb60925b1,0x800,0x1e8000)/File(EFI\debian\shimx64.efi)5c004500460049005c00730079007300740065006d0064005c00730079007300740065006d0064002d0062006f006f0074007800360034002e0065006600690020005c003000
Boot2001* EFI USB Device	RC
Boot2002* EFI DVD/CDROM	RC
Boot2003* EFI Network	RC
```

Welcome to `Boot0006` and it's first in `BootOrder`. It's time to reboot!

After reboot, we can check that `CurrentBoot` is `0006`. We can also uninstall `grub` and clean EFI bootloaders.

```
sudo apt purge grub-efi-amd64-* --allow-remove-essential
sudo efibootmgr -B -b 0000
sudo efibootmgr -B -b 0003
# let's also remove windows and PXE
sudo efibootmgr -B -b 0001
sudo efibootmgr -B -b 0002
sudo efibootmgr -B -b 0004
```

## Ukify