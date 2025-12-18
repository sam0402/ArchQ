#!/bin/bash
mpdver=0.23.17-24
mympdver=20.0.0-1
lmsver=9.1-1

c_blue_b=$'\e[1;38;5;27m'
c_gray=$'\e[m'

cpus=$(getconf _NPROCESSORS_CONF)
iso_1st=$((cpus-1)); iso_2nd=$((cpus/2-1))

servs=''
pacman -Q lyrionmusicserver >/dev/null 2>&1 && servs+='lyrionmusicserver '
pacman -Q mpd >/dev/null 2>&1 && servs+='mpd '
pacman -Q mympd >/dev/null 2>&1 && servs+='mympd '
pacman -Q roonserver >/dev/null 2>&1 && servs+='roonserver '
pacman -Q hqplayerd >/dev/null 2>&1 && servs+='hqplayerd '
pacman -Q nginx >/dev/null 2>&1 && servs+='nginx php-fpm '

server=$(dialog --stdout --title "ArchQ $1" --menu "Select music server" 7 0 0 \
        LMS "Lyrion Music Server" \
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
                mU "Ultra Light: PCM, FLAC only; best SQ" off \
                mL "Light: PCM, FLAC, DSD; plays CD" off \
                mS "Stream: PCM, FLAC; MP3 radio; http:8000" on \
                mD "DStream: +DSD to the Stream version" off \
                mM "MPEG: All features of the above; +AAC, ALAC" off ) || exit 1
        ;;
    myMPD)
        server=$(dialog --stdout --title "ArchQ" \
                --radiolist "Select MPD version" 7 0 0 \
                yU "Ultra Light: PCM, FLAC only; best SQ" off \
                yL "Light: PCM, FLAC, DSD; plays CD" off \
                yS "Stream: PCM, FLAC; MP3 radio; http:8000" on \
                yD "DStream: +DSD to the Stream version" off \
                yM "MPEG: All features of the above; +AAC, ALAC" off ) || exit 1
        ;;
    RompR)
        server=$(dialog --stdout --title "ArchQ" \
                --radiolist "Select MPD version" 7 0 0 \
                oU "Ultra Light: PCM, FLAC only; best SQ" off \
                oL "Light: PCM, FLAC, DSD; plays CD" off \
                oS "Stream: PCM, FLAC; MP3 radio; http:8000" on \
                oD "DStream: +DSD to the Stream version" off \
                oM "MPEG: All features of the above; +AAC, ALAC" off ) || exit 1
        ;;
esac
clear
case $server in
    Player)  
        # sed -i 's/'"$isocpu"'//' /etc/default/grub
        /usr/bin/player-cfg.sh
        ;;
    LMS)
        if ! pacman -Q lyrionmusicserver >/dev/null 2>&1; then
            isocpu="isolcpus=$iso_1st rcu_nocbs=$iso_1st "
            echo -e "\n${c_blue_b}Install Lyrion Music Server ...${c_gray}\n"
            pacman -S perl-webservice-musicbrainz perl-musicbrainz-discid perl-net-ssleay perl-io-socket-ssl perl-uri perl-mojolicious
            wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/lyrionmusicserver-${lmsver}-x86_64.pkg.tar.xz
            pacman -U --noconfirm /tmp/lyrionmusicserver-${lmsver}-x86_64.pkg.tar.xz
            [ $cpus -ge 4 ] && sed -i 's/^PIDFile/#PIDFile/;/ExecStart=/iType=idle\nNice=-20\nExecStartPost=/usr/bin/taskset -cp '"$iso_1st"' $MAINPID' /usr/lib/systemd/system/lyrionmusicserver.service
            [ $cpus -ge 6 ] && pacman -Q squeezelite >/dev/null 2>&1 && sed -i 's/^PIDFile/#PIDFile/;/ExecStart=/iType=idle\nNice=-20\nExecStartPost=/usr/bin/taskset -cp '"$iso_2nd"' $MAINPID' /usr/lib/systemd/system/lyrionmusicserver.service
            sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="'"$isocpu"'"/' /etc/default/grub
            sed -i 's/novideo/novideo --charset=utf8/' /usr/lib/systemd/system/lyrionmusicserver.service
            sed -i 's|ExecStart=|ExecStart=/usr/bin/pagecache-management.sh |' /usr/lib/systemd/system/lyrionmusicserver.service
        fi

        servs=${servs/lyrionmusicserver/}
        systemctl disable --now $servs
        systemctl enable --now lyrionmusicserver
        
        sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="'"$isocpu"'"/' /etc/default/grub
        grub-mkconfig -o /boot/grub/grub.cfg
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

        servs=${servs/roonserver/}
        systemctl disable --now $servs
        systemctl enable --now roonserver
        ;;
    m?|y?|o?)
        isocpu="rcu_nocbs=0-$iso_1st "
        if ! grep -q 'eLo' /etc/rc.local; then
        sed -i '$d' /etc/rc.local
        cat >>/etc/rc.local <<EOF
if systemctl is-active mpd >/dev/null; then
    mpc enable ArchQ >/dev/null 2>&1
    chrt -fp 85 \$(pgrep mpd)
    chrt -fp 54 \$(pgrep ksoftirqd/\$(ps -eLo comm,cpuid | grep "output:ArchQ" | awk '{print \$2}'))
EOF
        if [ $cpus -ge 6 ]; then
        cat >>/etc/rc.local <<EOF
    while read PID; do 
        taskset -cp 0-$((iso_1st-1)) \$PID
    done <<< \$(ps -eLo command,comm,tid,psr | grep -v '^\[\|output' | grep '$iso_1st\$' | awk '{print \$(NF-1)}')
EOF
        fi
        cat >>/etc/rc.local <<EOF
fi

EOF
    fi
        [[ $server =~ .U ]] && MPD=ul
        [[ $server =~ .L ]] && MPD=light
        [[ $server =~ .S ]] && MPD=stream
        [[ $server =~ .D ]] && MPD=dstream
        [[ $server =~ .M ]] && MPD=ffmpeg
        [[ $MPD == ul || $MPD == light ]] || wget -O - https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/upmpdcli.tar | tar xf - -C /tmp

        if ! pacman -Q mpd-${MPD} >/dev/null 2>&1; then
            echo -e "\n${c_blue_b}Install MPD-${MPD} ...${c_gray}\n"
            if ! pacman -Q mpd_cdrom >/dev/null 2>&1 ; then
                wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd_cdrom-1.0.0-1-any.pkg.tar.zst
                wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd-plugin-0.3.5-1-x86_64.pkg.tar.zst
                wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/vmtouch-1.3.1-1-any.pkg.tar.zst
                wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/socat-1.7.4.4-1-x86_64.pkg.tar.zst
                wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/owntone-28.6-1-x86_64.pkg.tar.zst
                wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/libsndfile-1.2.0-3-x86_64.pkg.tar.zst
                wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/ffmpeg-2\:5.1.2-12-x86_64.pkg.tar.zst
                pacman -U --noconfirm /tmp/*.pkg.tar.zst
                sed -i '58,92d' /usr/bin/mpd-plugin.py
                sed -i 's/daemon.socket/daemon.service/;s/pulseaudio/mpd/;/ExecStart=/i ExecStartPre=systemctl start avahi-daemon' /etc/systemd/system/owntone.service
                sed -i 's/daemon.socket/daemon.service/;s/pulseaudio/mpd/;/ExecStart=/i ExecStartPre=systemctl start avahi-daemon' /etc/systemd/system/owntone\@.service
                sed -i '$d' /etc/rc.local
                curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd-proxy\@.service >/etc/systemd/system/mpd-proxy\@.service
            fi
            if [[ $(pacman -Q mpd-${MPD} | awk '{print $2}') != ${mpdver} ]]; then
                wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd-${MPD}-${mpdver}-x86_64.pkg.tar.zst
                pacman -R --noconfirm $(pacman -Q mpd | awk '{print $1}')
                pacman -U --noconfirm /tmp/mpd-${MPD}-${mpdver}-x86_64.pkg.tar.zst
                sed -i 's/album,title/album,albumartist,title/' /etc/mpd.conf
                sed -i 's|ExecStart=|ExecStart=/usr/bin/pagecache-management.sh |' /usr/lib/systemd/system/mpd.service
                systemctl enable --now mpd mpd.socket
            fi
        fi
        if [[ $server =~ y. ]]; then
            pacman -Q mympd >/dev/null 2>&1 || wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mympd-${mympdver}-x86_64.pkg.tar.zst
            pacman -Q libnewt >/dev/null 2>&1 || wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/libnewt-0.52.24-2-x86_64.pkg.tar.zst
            mkdir -p /var/lib/private/mympd/config/
            echo 'Unknown' >/var/lib/private/mympd/config/album_group_tag
            pacman -U --noconfirm /tmp/*.pkg.tar.zst
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
            chmod 644 /etc/nginx/sites-enabled/*
            systemctl enable nginx php-fpm avahi-daemon
        fi
# cpu isolation
        if [ $cpus -ge 6 ]; then
            echo cpu isolation ...
            sed -i '/dop/i\\tcpu_affinity\t"'"$iso_1st"'"' /etc/mpd.conf
            sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="'"$isocpu"'"/' /etc/default/grub
            grub-mkconfig -o /boot/grub/grub.cfg
        fi
        ### Start mpd.. etc. service
        servs=${servs/mpd/}
        systemctl disable --now $servs mpd.socket
        # /usr/bin/mpd-cfg.sh
        usermod -aG optical mpd
        systemctl enable --now mpd
        server=MPD
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

        servs=${servs/hqplayerd/}
        systemctl disable --now $servs
        systemctl enable --now hqplayerd
        ;;
esac
echo ${c_blue_b}${server}${c_gray}" is started."