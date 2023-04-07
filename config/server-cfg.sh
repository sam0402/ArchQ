#!/bin/bash
c_blue_b=$'\e[1;38;5;27m'
c_gray=$'\e[m'
server=$(dialog --stdout --title "ArchQ $1" --menu "Select music server" 7 0 0 L LMS M "MPD & RompR" R Roon P Player) || exit 1; clear
case $server in
    P)
        /usr/bin/player-cfg.sh
        ;;
    L)
        if ! pacman -Q logitechmediaserver >/dev/null 2>&1; then
            cpus=$(getconf _NPROCESSORS_ONLN)
            iso_1st=$((cpus-1)); iso_2nd=$((cpus/2-1))
            isocpu=''
            echo -e "\n${c_blue_b}Install Logitech Media Server ...${c_gray}\n"
            wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/logitechmediaserver-8.2.0-2-x86_64.pkg.tar.xz
            pacman -U --noconfirm /root/logitechmediaserver-8.2.0-2-x86_64.pkg.tar.xz
            [ $cpus -ge 4 ] && sed -i 's/^PIDFile/#PIDFile/;/ExecStart=/iType=idle\nNice=-20\nExecStartPost=/usr/bin/taskset -cp '"$iso_1st"' $MAINPID' /usr/lib/systemd/system/logitechmediaserver.service
            [ $cpus -ge 6 ] && pacman -Q squeezelite >/dev/null 2>&1 && sed -i 's/^PIDFile/#PIDFile/;/ExecStart=/iType=idle\nNice=-20\nExecStartPost=/usr/bin/taskset -cp '"$iso_2nd"' $MAINPID' /usr/lib/systemd/system/logitechmediaserver.service
            sed -i 's/novideo/novideo --charset=utf8/' /usr/lib/systemd/system/logitechmediaserver.service
        fi
        pacman -Q mpd-light >/dev/null 2>&1 && systemctl disable --now mpd nginx php-fpm
        pacman -Q mpd-light >/dev/null 2>&1 && systemctl disable --now mympd
        [[ -d '/opt/RoonServer' ]] && systemctl disable --now roonserver
        systemctl enable --now logitechmediaserver
        ;;
    R)
        if [[ ! -d '/opt/RoonServer' ]]; then
            echo -e "\n${c_blue_b}Install Roon Server ...${c_gray}\n"
            mkdir -p /opt/RoonServer /usr/share/licenses/roonserver
            wget -qO - http://download.roonlabs.com/builds/RoonServer_linuxx64.tar.bz2 | bsdtar xf - -C /opt
            curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/roonserver.service >/usr/lib/systemd/system/roonserver.service
            chmod 644 /usr/lib/systemd/system/roonserver.service
            curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/roon_copyright >/usr/share/licenses/roonserver/COPYING
            sed -i 's/exec "$HARDLINK" "$SCRIPT.dll" "$@"/exec nice -n -20 "$HARDLINK" "$SCRIPT.dll" "$@"/g' /opt/RoonServer/Appliance/RAATServer
        fi
        pacman -Q mpd-light >/dev/null 2>&1 && systemctl disable --now mpd nginx php-fpm
        pacman -Q mpd-light >/dev/null 2>&1 && systemctl disable --now mympd
        pacman -Q logitechmediaserver >/dev/null 2>&1 && systemctl disable --now logitechmediaserver
        systemctl enable --now roonserver
        ;;
    M)
        if ! pacman -Q mpd-light >/dev/null 2>&1; then
            echo -e "\n${c_blue_b}Install MPD ...${c_gray}\n"
            wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd-light-0.23.11-4-x86_64.pkg.tar.zst
            wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd_cdrom-1.0.0-1-any.pkg.tar.zst
            wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/rompr-2.00-1-any.pkg.tar.zst
            wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/owntone-28.5-1-x86_64.pkg.tar.zst
            wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/blissify-0.3.3-1-x86_64.pkg.tar.zst
            pacman -U --noconfirm /root/mpd-light-0.23.11-4-x86_64.pkg.tar.zst /root/mpd_cdrom-1.0.0-1-any.pkg.tar.zst /root/rompr-2.00-1-any.pkg.tar.zst
            pacman -U --noconfirm /root/owntone-28.5-1-x86_64.pkg.tar.zst /root/blissify-0.3.3-1-x86_64.pkg.tar.zst

    ### setup mpd
            sed -i '$d' /etc/rc.local
            cat >>/etc/rc.local <<EOF
if systemctl is-active mpd >/dev/null; then
    ps H -q `pidof -s mpd` -o 'tid,cls' | grep FF | awk '{print \$1}' | while read PROC; do chrt -p 95 \$PROC; done
    chrt -fp 85 `pgrep mpd`
fi
exit 0
EOF
            ### Setup RompR
            mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
            sed -i '$i include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
            curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/rompr_nginx >/etc/nginx/sites-available/rompr
            sed -i 's/hostname/'"${HOSTNAME,,}"'/' /etc/nginx/sites-available/rompr
            sed -i 's/max_execution_time =.*/max_execution_time = 1800/;s/post_max_size =.*/post_max_size = 256M/;s/upload_max_filesize =.*/upload_max_filesize = 10M/;s/max_file_uploads =.*/max_file_uploads = 200/' /etc/php/php.ini
            sed -i 's/;extension=pdo_sqlite/extension=pdo_sqlite/;s/;extension=gd/extension=gd/;s/;extension=intl/extension=intl/' /etc/php/php.ini
            sed -i '/ExecStart=/i ExecStartPre=mkdir -p \/var\/log\/nginx' /usr/lib/systemd/system/nginx.service
            ln -s /etc/nginx/sites-available/rompr /etc/nginx/sites-enabled/rompr
            chmod 644 /etc/nginx/sites-enabled/rompr
        fi
        ### Start mpd.. etc. service
        pacman -Q logitechmediaserver >/dev/null 2>&1 && systemctl disable --now logitechmediaserver
        [[ -d '/opt/RoonServer' ]] && systemctl disable --now roonserver
        /usr/bin/mpd-cfg.sh
        systemctl enable --now mpd
        ;;
esac
yes | pacman -Scc
rm -f /root/*.tar.zst /root/*.tar.xz
