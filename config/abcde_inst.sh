#!/bin/bash
paceman -Syu --noconfirm
paceman -S --noconfirm glyr cdparanoia libdiscid fdkaac
wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/abcde-2.9.3-5-any.pkg.tar.zst
wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/cd-discid-1.4-3-x86_64.pkg.tar.zst
pacman -U --noconfirm /root/cd-discid-1.4-3-x86_64.pkg.tar.zst /root/abcde-2.9.3-5-any.pkg.tar.zst
cpan install MusicBrainz::DiscID
cpan install WebService::MusicBrainz
curl -sL /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/abcde_flac_wav.conf >/etc/abcde.conf
