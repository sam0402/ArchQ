rm -f /root/*.tar.zst /root/*.tar.xz*
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/ether-cfg.sh >/usr/bin/ether-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/kernel-cfg.sh >/usr/bin/kernel-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/cpu-cfg.sh >/usr/bin/cpu-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/mpd-cfg.sh >/usr/bin/mpd-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/nfs-cfg.sh >/usr/bin/nfs-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/nfserver-cfg.sh >/usr/bin/nfserver-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/smb-cfg.sh >/usr/bin/smb-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/partimnt-cfg.sh >/usr/bin/partimnt-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/player-cfg.sh >/usr/bin/player-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/shairport-cfg.sh >/usr/bin/shairport-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/sqzlite-cfg.sh >/usr/bin/sqzlite-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/desktop-cfg.sh >/usr/bin/desktop-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/abcde-cfg.sh >/usr/bin/abcde-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/bcache-cfg.sh >/usr/bin/bcache-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/datacache-cfg.sh >/usr/bin/datacache-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/zerowipe.sh >/usr/bin/zerowipe.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/config.sh >/usr/bin/config.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/sw >/usr/bin/sw
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/mpd_inst.sh >/usr/bin/mpd_inst.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/qboot >/usr/bin/qboot
# [ -f /root/alsa-lib-1.1.9-2-x86_64.pkg.tar.zst ] || wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/alsa-lib-1.1.9-2-x86_64.pkg.tar.zst
#  pacman -R --noconfirm alsa-utils; pacman -U --noconfirm --overwrite '*' /root/alsa-lib-1.1.9-2-x86_64.pkg.tar.zst
#  pacman -Sd --noconfirm alsa-utils
chmod +x /usr/bin/*.sh /usr/bin/qboot /usr/bin/sw
[ -f '/etc/squeezelite.conf' ] &&  sed -i 's/^OPTIONS="-W .*/#OPTIONS="-W "/' /etc/squeezelite.conf