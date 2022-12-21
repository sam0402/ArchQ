#!/bin/bash
wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd-light-0.23.9-4-x86_64.pkg.tar.zst
wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd_cdrom-1.0.0-1-any.pkg.tar.zst
pacman -U --noconfirm /root/mpd-light-0.23.9-4-x86_64.pkg.tar.zst /root/mpd_cdrom-1.0.0-1-any.pkg.tar.zst
pacman -Sy --noconfirm archlinux-keyring mympd avahi mpc
systemctl enable --now mympd avahi-daemon
/usr/bin/update_scpt.sh
/usr/bin/mpd-cfg.sh
