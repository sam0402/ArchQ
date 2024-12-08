#!/bin/bash
c_blue_b=$'\e[1;38;5;27m'
c_gray=$'\e[m'
server=$(dialog --stdout --title "ArchQ $1" --menu "Select music server" 7 0 0 \
        LMS "Logitech Media Server" \
        MPD "MPD, Rigelian(iOS) | text-based client" \
        myMPD "MPD & myMPD web-based client" \
        RompR "MPD & RompR web-based client" \
        Roon "Roon Server" \
        HQPE5 "HQPlayer Embedded 5" \
        HQPE4 "HQPlayer Embedded 4" \
        Player "Airplay | Squeezelite | Roonbridge | HQP NAA" ) || exit 1; clear
yes | pacman -Scc
case $server in
    MPD)
       server=$(dialog --stdout --title "ArchQ" \
                --radiolist "Select MPD version" 7 0 0 \
                mL "Light: pcm, flac" off \
                mS "Stream: +Light, dsd, radio" on \
                mM "MPEG: +Stream, mp3, aac, alac" off ) || exit 1
        ;;
    myMPD)
        server=$(dialog --stdout --title "ArchQ" \
                --radiolist "Select MPD version" 7 0 0 \
                yL "Light: pcm, flac" off \
                yS "Stream: +Light, dsd, radio" on \
                yM "MPEG: +Stream, mp3, aac, alac" off ) || exit 1
        ;;
    RompR)
       server=$(dialog --stdout --title "ArchQ" \
                --radiolist "Select MPD version" 7 0 0 \
                oL "Light: pcm, flac" off \
                oS "Stream: +Light, dsd, radio" on \
                oM "MPEG: +Stream, mp3, aac, alac" off ) || exit 1
        ;;
esac
case $server in
    Player)  
        sed -i 's/'"$isocpu"'//' /etc/default/grub
        /usr/bin/player-cfg.sh
        ;;
    LMS)
        if ! pacman -Q logitechmediaserver >/dev/null 2>&1; then
            cpus=$(getconf _NPROCESSORS_ONLN)
            iso_1st=$((cpus-1)); iso_2nd=$((cpus/2-1))
            isocpu="isolcpus=$iso_1st rcu_nocbs=$iso_1st "
            echo -e "\n${c_blue_b}Install Logitech Media Server ...${c_gray}\n"
            pacman -S perl-webservice-musicbrainz perl-musicbrainz-discid perl-net-ssleay perl-io-socket-ssl perl-uri perl-mojolicious
            wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/logitechmediaserver-8.4.0-1-x86_64.pkg.tar.xz
            pacman -U --noconfirm /tmp/logitechmediaserver-8.4.0-1-x86_64.pkg.tar.xz
            [ $cpus -ge 4 ] && sed -i 's/^PIDFile/#PIDFile/;/ExecStart=/iType=idle\nNice=-20\nExecStartPost=/usr/bin/taskset -cp '"$iso_1st"' $MAINPID' /usr/lib/systemd/system/logitechmediaserver.service
            [ $cpus -ge 6 ] && pacman -Q squeezelite >/dev/null 2>&1 && sed -i 's/^PIDFile/#PIDFile/;/ExecStart=/iType=idle\nNice=-20\nExecStartPost=/usr/bin/taskset -cp '"$iso_2nd"' $MAINPID' /usr/lib/systemd/system/logitechmediaserver.service
            sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="'"$isocpu"'"/' /etc/default/grub
            sed -i 's/novideo/novideo --charset=utf8/' /usr/lib/systemd/system/logitechmediaserver.service
        fi
        systemctl disable --now mpd nginx php-fpm mympd roonserver hqplayerd
        systemctl enable --now logitechmediaserver
        ;;
    Roon)
        if [[ ! -d '/opt/RoonServer' ]]; then
            echo -e "\n${c_blue_b}Install Roon Server ...${c_gray}\n"
            mkdir -p /opt/RoonServer /usr/share/licenses/roonserver
            wget -O - http://download.roonlabs.com/builds/RoonServer_linuxx64.tar.bz2 | bsdtar xf - -C /opt
            curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/roonserver.service >/usr/lib/systemd/system/roonserver.service
            chmod 644 /usr/lib/systemd/system/roonserver.service
            curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/roon_copyright >/usr/share/licenses/roonserver/COPYING
            sed -i 's/exec "$HARDLINK" "$SCRIPT.dll" "$@"/exec nice -n -20 "$HARDLINK" "$SCRIPT.dll" "$@"/g' /opt/RoonServer/Appliance/RAATServer
        fi
        sed -i 's/'"$isocpu"'//' /etc/default/grub
        systemctl disable --now mpd nginx php-fpm mympd logitechmediaserver hqplayerd
        systemctl enable --now roonserver
        ;;
    m?|y?|o?)
        [[ $server =~ .L ]] && MPD=light
        [[ $server =~ .S ]] && MPD=stream
        [[ $server =~ .M ]] && MPD=ffmpeg
        if ! pacman -Q mpd-${MPD} >/dev/null 2>&1; then
            echo -e "\n${c_blue_b}Install MPD-${MPD} ...${c_gray}\n"
            wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd-${MPD}-0.23.14-12-x86_64.pkg.tar.zst
            wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd_cdrom-1.0.0-1-any.pkg.tar.zst
            wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/owntone-28.6-1-x86_64.pkg.tar.zst
            wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd-plugin-0.3.5-1-x86_64.pkg.tar.zst
            pacman -U --noconfirm /tmp/mpd-*.pkg.tar.zst
            sed -i '58,92d' /usr/bin/mpd-plugin.py
            sed -i 's/daemon.socket/daemon.service/;s/pulseaudio/mp.service avahi-daemon/' /etc/systemd/system/owntone\@.service
            if [[ $server =~ y. ]]; then
                wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mympd-12.1.1-1-x86_64.pkg.tar.zst
                # wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/libnewt-0.52.24-2-x86_64.pkg.tar.zst
                pacman -U --noconfirm /tmp/mympd-*.pkg.tar.zst
                systemctl enable mympd
            fi
            if [[ $server =~ o. ]]; then
                wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/rompr-2.00-1-any.pkg.tar.zst
                pacman -U --noconfirm /tmp/rompr-*.pkg.tar.zst
                ### Setup RompR
                mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
                sed -i '$i include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
                curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/rompr_nginx >/etc/nginx/sites-available/rompr
                curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/cantata_nginx >/etc/nginx/sites-available/cantata
                sed -i 's/hostname/'"${HOSTNAME,,}"'/' /etc/nginx/sites-available/rompr
                sed -i 's/hostname/'"${HOSTNAME,,}"'/' /etc/nginx/sites-available/cantata
                sed -i 's/max_execution_time =.*/max_execution_time = 1800/;s/post_max_size =.*/post_max_size = 256M/;s/upload_max_filesize =.*/upload_max_filesize = 10M/;s/max_file_uploads =.*/max_file_uploads = 200/' /etc/php/php.ini
                sed -i 's/;extension=pdo_sqlite/extension=pdo_sqlite/;s/;extension=gd/extension=gd/;s/;extension=intl/extension=intl/' /etc/php/php.ini
                sed -i '/ExecStart=/i ExecStartPre=mkdir -p \/var\/log\/nginx' /usr/lib/systemd/system/nginx.service
                ln -s /etc/nginx/sites-available/rompr /etc/nginx/sites-enabled/rompr
                ln -s /etc/nginx/sites-available/cantata /etc/nginx/sites-enabled/cantata
                chmod 644 /etc/nginx/sites-enabled/rompr
                systemctl enable nginx php-fpm avahi-daemon
            fi
    ### setup mpd
            sed -i '$d' /etc/rc.local
            cat >>/etc/rc.local <<EOF
if systemctl is-active mpd >/dev/null; then
    ps H -q `pidof -s mpd` -o 'tid,cls' | grep FF | awk '{print \$1}' | while read PROC; do chrt -p 95 \$PROC; done
    chrt -fp 85 `pgrep mpd`
fi
exit 0
EOF

            chmod 644 /etc/nginx/sites-enabled/cantata
        fi
        ### Start mpd.. etc. service
        sed -i 's/'"$isocpu"'//' /etc/default/grub
        systemctl disable --now logitechmediaserver roonserver hqplayerd mpd.socket
        /usr/bin/mpd-cfg.sh
        usermod -aG optical mpd
        systemctl enable --now mpd
        ;;
    HQPE4|HQPE5)
        echo -e "\n${c_blue_b}Install HQPlayer Embedded${server:4:1}...${c_gray}\n"
        if ! pacman -Q gupnp-dlna >/dev/null 2>&1; then
            wget -O - https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/hqplayerd-lib.tar.gz | tar zxf - -C /tmp
            wget -P /tmp/hqplayerd-lib https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/gtk3-1%3A3.24.37-1-x86_64.pkg.tar.zst
            pacman -U --noconfirm /tmp/hqplayerd-lib/*.pkg.tar.zst
        fi
        ## install hqplayerd
        systemctl disable --now hqplayerd
        hqe_deb=$(wget -O - https://www.signalyst.eu/bins/hqplayerd/jammy/ | grep "hqplayerd_${server:4:1}" | grep _amd64.deb | tail -n1 | awk -F'"' '{print $2}')
        wget -O - "https://www.signalyst.eu/bins/hqplayerd/jammy/$hqe_deb" | bsdtar xf - -C /tmp
        mkdir -p /tmp/hqpd
        bsdtar xf /tmp/data.tar.zst -C /tmp/hqpd
        rm -rf /tmp/hqpd/lib
        cp -af /tmp/hqpd/* /.
        install -Dm644 "/usr/share/doc/hqplayerd/copyright" "/usr/share/licenses/hqplayer/COPYING"
        rm "/usr/share/doc/hqplayerd/copyright"
        mkdir -p /var/lib/hqplayer/home
        chown -R root:root /var/lib/hqplayer
        chown -R root:root /etc/hqplayer
        curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/hqplayerd.service >/usr/lib/systemd/system/hqplayerd.service

        ## lib link
        cd /usr/lib
        [ ! -f "libgupnp-1.2.so.0" ] && ln -s libgupnp-1.2.so.1 libgupnp-1.2.so.0
        [ ! -f "libgupnp-av-1.0.so.2" ] && ln -s libgupnp-av-1.0.so.3 libgupnp-av-1.0.so.2
        [ ! -f "libomp.so.5" ] && ln -s libomp.so libomp.so.5
        [ ! -f "libFLAC.so.8" ] && ln -s libFLAC.so.12 libFLAC.so.8
        [ ! -f "libsgllnx64-2.29.02.so" ] && [ -f "/opt/hqplayerd/lib/libsgllnx64-2.29.02.so" ] && ln -s /opt/hqplayerd/lib/libsgllnx64-2.29.02.so libsgllnx64-2.29.02.so
        [ ! -f "libsglarm64-2.31.0.0.so" ] && [ -f "/opt/hqplayerd/lib/libsglarm64-2.31.0.0.so" ] && ln -s /opt/hqplayerd/lib/libsglarm64-2.31.0.0.so libsglarm64-2.31.0.0.so
        if [ ! -f "/etc/pki/tls/certs/ca-bundle.crt" ]; then
            mkdir -p /etc/pki/tls/certs
            ln -s /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt
        fi
        systemctl disable --now mpd nginx php-fpm mympd logitechmediaserver roonserver
        systemctl enable --now hqplayerd
        ;;
esac
