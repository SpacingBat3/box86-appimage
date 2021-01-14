# box86-appimage
A group of the bash scripts used to package the [`box86`](https://github.com/ptitSeb/box86) into the AArch64 or ARMv7 AppImage.

## 1. Usage
```
git clone https://github.com/SpacingBat3/box86-appimage && box86-appimage/package
```

## 2. Todo:
- [X] Package for the AArch64 targets.
    - [X] AArch64 hosts
    - [ ] ARMv7 hosts
- [X] Package for the ARMv7 targets.
    - [X] AArch64 hosts
    - [ ] ARMv7 hosts
- [X] Building the chroot using the existing chroot directory.
    - [X] Selectively copy the libraries from the chroot.
- [ ] Building using the toolchain (on any host architecture).
- [X] Create the new chroot enviroment on Arch-based Linux distributions and use it to build `box86`.

## 3. License:
This project is redistributed under the conditions of the GNU GPL License (version 3 or later).