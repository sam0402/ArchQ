Install ArchQ PKGs with compiling optimization by file size (Os).

$ `su`

Install ALSA library

`wget -P /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg_S/alsa-lib-1.1.9-2-x86_64.pkg.tar.zst`

`pacman -U --noconfirm --overwrite '*' /root/alsa-lib-1.1.9-2-x86_64.pkg.tar.zst`

`pacman -Sd --noconfirm alsa-utils`

Download PKGs for need.

`wget -P /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg_S/cdparanoia-10.2-9-x86_64.pkg.tar.zst`

`wget -P /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg_S/mpd-light-0.23.5-1-x86_64.pkg.tar.zst`

`wget -P /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg_S/shairport-sync-3.3.9-1-x86_64.pkg.tar.zst`

`wget -P /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg_S/shairport-sync-3.3.9-2-x86_64.pkg.tar.zst`

`wget -P /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg_S/squeezelite-1.9.8.1317-dsd-x86_64.pkg.tar.zst`

`wget -P /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg_S/squeezelite-1.9.8.1317-pcm-x86_64.pkg.tar.zst`

Install PKGs

`pacman -U /root/*-x86_64.pkg.tar.zst`
