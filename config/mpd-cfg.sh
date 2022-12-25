#!/bin/bash
config='/etc/mpd.conf'
user=$(grep '1000' /etc/passwd | awk -F: '{print $1}')

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

client=$(dialog --stdout --title "ArchQ MPD" --menu "Select MPD client" 7 0 0 R "RompR :6660" M "myMPD :80" N "Ncmpcpp curses" U "Multi user") || exit 1
clear
case $client in
    R)
        pacman -Q mympd >/dev/null 2>&1 && systemctl disable --now mympd
        systemctl enable --now mpd nginx php-fpm avahi-daemon
        ;;
    M)
        pacman -Q mympd >/dev/null 2>&1 || pacman -Sy --noconfirm archlinux-keyring mympd
        systemctl disable --now nginx php-fpm avahi-daemon
        systemctl enable --now mpd mympd
        ;;
    N)
        pacman -Q ncmpcpp >/dev/null 2>&1 || pacman -Sy --noconfirm archlinux-keyring ncmpcpp tmux
        systemctl disable --now nginx php-fpm avahi-daemon
        pacman -Q mympd >/dev/null 2>&1 && systemctl disable --now mympd
        ;;
    U)
        if [[ ! -d /usr/share/mpd ]]; then
            curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd_config.tar.gz | tar -xz -C /usr/share
            curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/mpdconf >/usr/bin/mpdconf
            chmod +x /usr/bin/mpdconf
        fi
        users=$(dialog --stdout --title "ArchQ MPD multi" --inputbox "Add users" 0 25 0) || exit 1
        clear
        num=$(grep 'mpd' /etc/passwd | wc -l)
        users=$(( $users + $num - 1 ))
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
    echo "No Sound Device" ; exit 1
fi
devs='hw:0,0 　 '
while read line; do
    devs+=${line}' 　 '
done <<< $(aplay -L | grep ':')

device=$(dialog --stdout \
        --title "ArchQ $1" \
        --menu "MPD ouput device" 7 0 0 ${devs}) || exit 1
clear
sed -i 's/^#\?.* \?\tdevice.*"/\tdevice\t'"\"$device\""'/' $config

### Volume Control
vol_ctrl ALSA $config

### Include audio output
p0=off; h0=off
p1=off; h1=off
cat $config | grep pulse | grep -q '#' || p0=on 
cat $config | grep httpd | grep -q '#' || h0=on
output=$(dialog --stdout --title "ArchQ MPD" \
        --checklist "Include output" 7 0 0 \
        A Airplay $p0 H Httpd $h0 ) || exit 1
clear
[[ $output =~ A ]] && p1=on
[[ $output =~ H ]] && h1=on

if [[ $p1 == on ]]; then
    vol_ctrl Airplay /etc/mpd.d/pulse.out
    sed -i 's/^#.\?include_optional "mpd.d\/pulse.out"/include_optional "mpd.d\/pulse.out"/' $config
    systemctl enable --now avahi-daemon
    user=$(grep '1000' /etc/passwd | awk -F: '{print $1}')
    echo "Use command 'pulse_airport' to set Airport output device @$user."
else
    sed -i 's/^include_optional "mpd.d\/pulse.out"/#include_optional "mpd.d\/pulse.out"/' $config
    systemctl --user -M $user@ disable pipewire pipewire-pulse sinkdef
fi

if [[ $h1 == on ]]; then
    ht_conf='/etc/mpd.d/httpd.out'
    sed -i 's/^#.\?include_optional "mpd.d\/httpd.out"/include_optional "mpd.d\/httpd.out"/' $config
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

### Music direcroty 
mdir=$(grep 'music_directory' $config | cut -d'"' -f2 | cut -d'/' -f3-)

mdir=$(dialog --stdout \
    --title "ArchQ MPD" \
    --ok-label "Ok" \
    --form "Music directory" 0 30 0 \
    " /mnt/"  1 1 $mdir 1 7 30 0) || exit 1
clear
mdir=$(echo $mdir | sed 's"/"\\\/"g')
sed -i 's/^#\?music_directory.*"/music_directory "\/mnt\/'"$mdir"'"/' $config

systemctl restart mpd
