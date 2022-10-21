rm -f /root/*.tar.zst /root/*.tar.xz*
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/ether-cfg.sh >/usr/bin/ether-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/kernel-cfg.sh >/usr/bin/kernel-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/cpu-cfg.sh >/usr/bin/cpu-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/mpd-cfg.sh >/usr/bin/mpd-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/nfs-cfg.sh >/usr/bin/nfs-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/smb-cfg.sh >/usr/bin/smb-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/partimnt-cfg.sh >/usr/bin/partimnt-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/player-cfg.sh >/usr/bin/player-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/shairport-cfg.sh >/usr/bin/shairport-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/sqzlite-cfg.sh >/usr/bin/sqzlite-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/desktop-cfg.sh >/usr/bin/desktop-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/abcde-cfg.sh >/usr/bin/abcde-cfg.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/config.sh >/usr/bin/config.sh
curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/qboot >/usr/bin/qboot
chmod +x /usr/bin/*.sh /usr/bin/qboot
[ -f '/etc/squeezelite.conf' ] &&  sed -i 's/^OPTIONS="-W .*/#OPTIONS="-W "/' /etc/squeezelite.conf