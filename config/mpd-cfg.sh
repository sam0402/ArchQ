#!/bin/bash
config='/etc/mpd.conf'

client=$(dialog --stdout --title "ArchQ MPD" --menu "Select MPD client" 7 0 0 R "RompR :6660" M "myMPD :80" N "Ncmpcpp curses") || exit 1
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
        pacman -Q ncmpcpp >/dev/null 2>&1 || pacman -Sy --noconfirm archlinux-keyring ncmpcpp
        systemctl disable --now nginx php-fpm avahi-daemon
        pacman -Q mympd >/dev/null 2>&1 && systemctl disable --now mympd
        ;;
esac
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

### Volume Control
v_none='off'; v_soft='off'; v_hard='off'
case $(grep 'mixer_type' $config | cut -d'"' -f2) in
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
    --radiolist "Volume Control" 7 0 0 \
    none '　' $v_none \
    software '　' $v_soft \
    hardware '　' $v_hard) || exit 1
clear
sed -i 's/mixer_type.*"/mixer_type\t"'"$volume"'"/' $config 

### Audio output
alsa=on; pulse=off
if grep -q 'pulse' $config ; then
    alsa=off; pulse=on
fi
output=$(dialog --stdout \
    --title "ArchQ MPD" \
    --radiolist "Sound Output" 7 0 0 \
    S "Sound Card" $alsa \
    A "Airport" $pulse ) || exit 1

case $output in
    S)
        sed -i 's/type[[:space:]]*"pulse"/type\t"alsa"/' $config
        ### Select sound device
        if [ ! $(aplay -L | grep ':') ]; then
            echo "No Sound Device" ; exit 1
        fi

        while read line; do
            devs+=${line}' 　 '
        done <<< $(aplay -L | grep ':')

        device=$(dialog --stdout \
                --title "ArchQ $1" \
                --menu "MPD ouput device" 7 0 0 ${devs}) || exit 1
        clear
        sed -i 's/^#\?.* \?\tdevice.*"/\tdevice\t'"\"$device\""'/' $config
    ;;
    A)
        sed -i 's/type[[:space:]]*"alsa"/type\t"pulse"/' $config
        user=$(grep '1000' /etc/passwd | awk -F: '{print $1}')
        echo "Use command 'pulse_airport' to set Airport output device @$user."
    ;;
esac

systemctl restart mpd
