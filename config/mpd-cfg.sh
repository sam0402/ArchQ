#!/bin/bash
## modprobe brd rd_size=2621440 max_part=1 rd_nr=1
config='/etc/mpd.conf'
user=$(grep '1000' /etc/passwd | awk -F: '{print $1}')

### Volume Control none/software/hardware
vol_ctrl(){
    v_none='off'; v_soft='off'; v_hard='off'
    case $(grep 'mixer_type' $2 | cut -d'"' -f2) in
        none)
            v_none=on
            ;;
        software)
            v_soft=on
            ;;
        hardware)
            v_hard=on
            ;;
    esac
    volume=$(dialog --stdout \
        --title "ArchQ MPD" \
        --radiolist "$1 volume control" 7 0 0 \
        none '　' $v_none \
        software '　' $v_soft \
        hardware '　' $v_hard) || exit 1
    clear
    sed -i 's/mixer_type.*"/mixer_type\t"'"$volume"'"/' $2
}
### MPD client select
client=$(dialog --stdout --title "ArchQ MPD" --menu "Select MPD client" 7 0 0 R "RompR :6660" M "myMPD :80" C "Cantata :8080" N "Ncmpcpp ncurses" U "Multi user") || exit 1
clear
case $client in
    R)
        rm /etc/nginx/sites-enabled/cantata
        ln -s /etc/nginx/sites-available/rompr /etc/nginx/sites-enabled/rompr
        pacman -Q mympd >/dev/null 2>&1 && systemctl disable --now mympd php-fpm
        systemctl enable --now mpd nginx php-fpm avahi-daemon
        ;;
    M)
        pacman -Q mympd >/dev/null 2>&1 || (pacman -Sy --noconfirm archlinux-keyring mympd; yes | pacman -Scc >/dev/null 2>&1)
        systemctl disable --now nginx php-fpm avahi-daemon
        systemctl enable --now mpd mympd
        ;;
    N)
        pacman -Q ncmpcpp >/dev/null 2>&1 || (pacman -Sy --noconfirm archlinux-keyring ncmpcpp; yes | pacman -Scc >/dev/null 2>&1)
        systemctl disable --now nginx php-fpm avahi-daemon
        pacman -Q mympd >/dev/null 2>&1 && systemctl disable --now mympd php-fpm
        ;;
    C)  
        rm /etc/nginx/sites-enabled/rompr
        ln -s /etc/nginx/sites-available/cantata /etc/nginx/sites-enabled/cantata
        pacman -Q mympd >/dev/null 2>&1 && systemctl disable --now mympd php-fpm
        systemctl enable --now mpd nginx
        ;;
    U)
        if [[ ! -d /usr/share/mpd ]]; then
            curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd_config.tar.gz | tar -xz -C /usr/share
            curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/mpdconf >/usr/bin/mpdconf
            chmod +x /usr/bin/mpdconf
        fi
        users=$(dialog --stdout --title "ArchQ MPD multi" --inputbox "Add users" 0 25 0) || exit 1; clear
        num=$(grep 'mpd' /etc/passwd | wc -l)
        users=$(( $users + $num - 1 ))
        # Httpd stream multi user
        for ((i=$num; i <= $users; i++))
        do
            useradd -mU "mpd$i"
            sh -c "echo mpd$i:mpd | chpasswd"
            mkdir -p /home/mpd$i/.config
            cp -a /usr/share/mpd /home/mpd$i/.config
            chown -R mpd$i: /home/mpd$i/.config
            port=$(( $(id -u mpd$i) + 5600 ))
            sed -i 's/port.*"/port\t"'"$port"'"/' /home/mpd$i/.config/mpd/mpd.conf
            sport=$(( $(id -u mpd$i) + 7000 ))
            sed -i 's/port.*"/port\t"'"$sport"'"/' /home/mpd$i/.config/mpd/httpd.out
            ln -s /usr/lib/systemd/user/mpd.service /usr/lib/systemd/user/mpd$i.service
            cp /usr/lib/systemd/user/mpd.socket /usr/lib/systemd/user/mpd$i.socket
            sed -i 's/ListenStream=6600/ListenStream='"$port"'/' /usr/lib/systemd/user/mpd$i.socket
            systemctl enable --now avahi-daemon
            systemctl --user -M mpd$i@ enable mpd$i.socket
            echo "User mpd$i's control port: $port, stream port: $sport"
        done
        echo "Use command 'mpdcfg mpd[$num-$users]' to configure."
        exit 1
        ;;
esac

# ### Select sound device
if [ ! $(aplay -L | grep ':') ]; then
    dialog --title "ArchQ MPD $1" --msgbox "No Sound Device" 7 30
else
    devs='hw:0,0 　 '
    while read line; do
        devs+=${line}' 　 '
    done <<< $(aplay -L | grep ':')

    device=$(dialog --stdout \
            --title "ArchQ MPD $1" \
            --menu "Ouput device" 7 0 0 ${devs}) || exit 1; clear
    sed -i 's/^#\?.* \?\tdevice.*"/\tdevice\t'"\"$device\""'/' $config
fi

### ALSA ###
## Volume Control
vol_ctrl ALSA $config

### Include audio output & Dop
m0=off; h0=off; d0=off
m1=off; h1=off; d1=off
cat $config | grep owntone | grep -q '#' || m0=on 
cat $config | grep httpd | grep -q '#' || h0=on
cat $config | grep -q "#[[:space:]]dop" || d0=on
output=$(dialog --stdout --title "ArchQ MPD" \
        --checklist "Output" 7 0 0 \
        M Multiroom $m0 H Httpd $h0 D DoP $d0) || exit 1; clear
[[ $output =~ M ]] && m1=on
[[ $output =~ H ]] && h1=on
[[ $output =~ D ]] && d1=on

## Airplay multi room on/off
if [[ $m1 == on ]]; then
    [[ -d /var/lib/mpd/fifo ]] || install -o mpd -g mpd -m 755 -d /var/lib/mpd/fifo
    sed -i 's/^#.\?include_optional "mpd.d\/owntone.out"/include_optional\t"mpd.d\/owntone.out"/' $config
    systemctl start --now avahi-daemon.socket owntone
    # systemctl --user --now -M $user@ enable pipewire pipewire-pulse sinkdef
else
    sed -i 's/^include_optional "mpd.d\/owntone.out"/#include_optional\t"mpd.d\/owntone.out"/' $config
    systemctl --now disable owntone avahi-daemon.socket
fi

## Httpd stream output on/off
if [[ $h1 == on ]]; then
    ht_conf='/etc/mpd.d/httpd.out'
    sed -i 's/^#.\?include_optional "mpd.d\/httpd.out"/include_optional\t"mpd.d\/httpd.out"/' $config
    http_flac=off; http_wave=off
    [[ $(cat $ht_conf | grep 'encoder' $2 | cut -d'"' -f2) == 'flac' ]] && http_flac=on || http_wave=on
    encoder=$(dialog --stdout \
        --title "ArchQ MPD" \
        --radiolist "Httpd stream encoder" 7 0 0 \
        flac '　' $http_flac \
        wave '　' $http_wave) || exit 1
    clear
    sed -i 's/encoder.*"/encoder\t"'"$encoder"'"/' $ht_conf
else   
    sed -i 's/^include_optional "mpd.d\/httpd.out"/#include_optional "mpd.d\/httpd.out"/' $config
fi
## Dop on/off
[[ $d1 == on ]] && sed -i 's/^#.\?dop.*/\tdop\t"yes"/' $config || sed -i 's/^[[:space:]]dop.*/#\tdop\t"yes"/' $config

### Buffer, RAMDISK & Music Directory 
mdir=$(grep 'music_directory' $config | cut -d'"' -f2 | cut -d'/' -f3-)
buffer=$(grep 'audio_buffer_size' $config | cut -d'"' -f2 | cut -d'/' -f3-)
pertime=$(grep 'period_time' $config | cut -d'"' -f2 | cut -d'/' -f3-)
## Ramdisk 
ramdisk=$(grep 'rdsize=' /usr/bin/mpd-rdcheck.sh | awk -F'=' '{print $2}')
[[ $(systemctl is-active mpd-plugin) == 'inactive' ]] && rd_GB=0 || rd_GB=$(python -c "print(round($ramdisk/1048576,1))")
###
options=$(dialog --stdout \
    --title "ArchQ MPD" \
    --ok-label "Ok" \
    --form "Buffer, Ramdisk & Directory" 0 35 0 \
    "Audio Buffer >=128"  1 1 $buffer  1 20 35 0 \
    "Period Time(μs)"     2 1 $pertime 2 20 35 0 \
    "Ramdisk(GB)"         3 1 $rd_GB   3 20 35 0 \
    "Music Dir     /mnt/" 4 1 $mdir    4 20 35 0 ) || exit 1; clear

beffer=$(echo $options | awk '//{print $1 }')
pertime=$(echo $options | awk '//{print $2 }')
buftime=$(($pertime * 6))
mdir=$(echo $echo $options | awk '//{print $4}' | sed 's"/"\\\/"g')
## Set ramdisk
rd_GB=$(echo $options | awk '//{print $3 }')
if [ $rd_GB = '0' ]; then
    rm -f /var/lib/mpd/playlists/RAMDISK.m3u
    systemctl disable --now mpd-plugin
else
    ramdisk=$(python -c "print(int($rd_GB*1048576))")
    sed -i 's/rdsize=.*/rdsize='"$ramdisk"'/' /usr/bin/mpd-rdcheck.sh
    touch /tmp/RAMDISK.m3u
    install -Dm 644 -o mpd -g mpd /tmp/RAMDISK.m3u -t /var/lib/mpd/playlists/
    systemctl enable --now mpd-plugin
fi

sed -i 's/^#\?audio_buffer_size.*"/audio_buffer_size\t"'"$beffer"'"/' $config
sed -i 's/^#\?.* \?\tbuffer_time.*"/\tbuffer_time\t"'"$buftime"'"/;s/^#\?.* \?\tperiod_time.*"/\tperiod_time\t"'"$pertime"'"/' $config
sed -i 's/^#\?music_directory.*"/music_directory\t"\/mnt\/'"$mdir"'"/' $config

### Blissify scan music directory as mpd
[[ -f /etc/blissify.conf ]] && sed -i 's/"mpd_base_path": ".*/"mpd_base_path": "'"$mdir"'"/' /etc/blissify.conf

### Restart MPD
systemctl restart mpd