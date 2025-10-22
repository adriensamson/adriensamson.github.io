+++
title = "Full disk encryption unlocked by TPM on Trixie"
+++

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
sudo apt purge grub-efi-amd64-* grub2-common --allow-remove-essential
sudo efibootmgr -B -b 0000
sudo efibootmgr -B -b 0003
# let's also remove windows and PXE
sudo efibootmgr -B -b 0001
sudo efibootmgr -B -b 0002
sudo efibootmgr -B -b 0004
```

## Ukify

Now we're going to migrate to a [Unfied Kernel Image (UKI)](https://uapi-group.org/specifications/specs/unified_kernel_image/).
UKI permits to bundle a kernel, an initramfs and a command line together and sign it for SecureBoot.

SecureBoot helps to ensure that only trusted code is loaded on boot. All code is signed and the signature is checked against a key database.
In a typical Debian installations, this is the chain of trust:

1. The computer firmware running UEFI and trusts Microsoft's CA by default.
2. Debian's `shim` is signed by Microsoft and trusts Debian's CA.
3. Debian's kernel is signed by Debian's CA.

We can't make Debian or Microsoft sign our UKI, so we'll need to enroll our own key. Luckily `shim` permits to enroll MOK (Machine Owner Key).
Looking at `man ukify` and `man kernell-install`, we can find the interesting bits for configuration.

```
# Install
sudo apt install systemd-ukify mokutil

# switch kernel-install to ukify
echo layout=uki | sudo tee /etc/kernel/install.conf

# configure ukify (exemple #5)
sudo tee /etc/kernel/uki.conf <<EOF
[UKI]
SecureBootPrivateKey=/etc/kernel/secure-boot-key.pem
SecureBootCertificate=/etc/kernel/secure-boot-certificate.pem

[PCRSignature:initrd]
Phases=enter-initrd
PCRPrivateKey=/etc/systemd/tpm2-pcr-private-key-initrd.pem
PCRPublicKey=/etc/systemd/tpm2-pcr-public-key-initrd.pem

[PCRSignature:system]
Phases=enter-initrd:leave-initrd enter-initrd:leave-initrd:sysinit
       enter-initrd:leave-initrd:sysinit:ready
PCRPrivateKey=/etc/systemd/tpm2-pcr-private-key-system.pem
PCRPublicKey=/etc/systemd/tpm2-pcr-public-key-system.pem
EOF

# Generate the keys
sudo ukify genkey --config=/etc/kernel/uki.conf

# Optionally copy current cmdline and edit it (add splash for example)
sudo cp /proc/cmdline /etc/kernel/cmdline

# Reinstall systemd-boot entry with the new config
sudo kernel-install add $(uname -r) /boot/vmlinuz-$(uname -r)
```

Now, the UKI is generated and installed. We must enroll the keys with `mokutil` to allow boot with SecureBoot enabled.
`mokutil` with ask for a password, it will be asked during the enrollment by `shim` at early boot stage.
Be careful, your regular keyboard layout won't be loaded so choose a password you can type in a QWERTY layout.
Reboot and follow the steps in `shim`.

```
sudo openssl x509 -outform DER -in /etc/kernel/secure-boot-certificate.pem -out /etc/kernel/secure-boot-certificate.cer
sudo mokutil -i /etc/kernel/secure-boot-certificate.cer
sudo reboot
```

If everything is fine, you can check with `sudo bootctl`, that the current boot entry is a `.efi` file.

## Dracut

Debian's default initramfs doesn't handle advanced unlock strategies for LUKS disks.
So we'll need to use `systemd-crypsetup`, and the easiest way to have in initramfs is using `dracut`.
Trixie's `dracut` defaults to generic initramfs and doesn't include `/etc/crypttab` so we'll need to tell `kernel-install` to not take the default initramfs.
It already supports calling `dracut` with the good arguments.

```
sudo apt install dracut
sudo ln -s /dev/null /etc/kernel/install.d/55-initrd.install
# rebuild uki
sudo kernel-install add $(uname -r) /boot/vmlinuz-$(uname -r)
```

Since we do not use the default initramfs in `/boot`, we can cleanup some scripts to avoid rebuilding it at each kernel update.

```
sudo apt purge initramfs-tools
sudo rm /etc/kernel/postinst.d/dracut
sudo rm /etc/kernel/postrm.d/dracut
sudo rm /boot/initrd.img-*
```

## Cryptenroll

The last step is enrolling a TPM based key slot in LUKS.
The hardest thing to reason with TPM is choosing the right [PCR](https://uapi-group.org/specifications/specs/linux_tpm_pcr_registry/) to bind to.
`systemd-cryptsetup` allows two ways to bind a policy to PCR.
Firstly, binding to the content of the PCR at that time of boot. By default, `systemd-cryptenroll` binds to PCR 7 which is `SecureBoot` policy (is it enabled and which firmware keys are defined).
I will add PCR 14 which is measured against MOK in `shim`.

Secondly, it can bind to PCRs via a public key. It means that you won't have to re-enroll each time this part changes given that it's signed with the same key.
By default, `systemd-cryptenroll` binds to PCR 11, ie the UKI. That's why we created keys earlier with `uki.conf`.

```
# make sure dracut has tpm modules installed
sudo apt install tpm2-tools
echo 'add_dracutmodules+=" systemd-pcrphase "' | sudo tee /etc/dracut.conf.d/pcr.conf

sudo systemd-cryptenroll --tpm2-device=auto --tpm2-public-key=/etc/systemd/tpm2-pcr-public-key-initrd.pem --tpm2-pcrs=7+14
# edit crypttab to add option tpm2-device=auto
sudo nano /etc/crypttab

# rebuild UKI to include the new dracut modules and crypttab content
sudo kernel-install add $(uname -r) /boot/vmlinuz-$(uname -r)
```

Reboot, and that's all!
