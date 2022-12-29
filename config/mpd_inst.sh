#!/bin/bash
wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd-light-0.23.9-4-x86_64.pkg.tar.zst
wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd_cdrom-1.0.0-1-any.pkg.tar.zst
wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/owntone-28.5-1-x86_64.pkg.tar.zst
pacman -Sy --noconfirm archlinux-keyring
pacman -U --noconfirm /root/*.pkg.tar.zst
pacman -Sy --noconfirm mympd avahi mpc
systemctl enable --now mympd
