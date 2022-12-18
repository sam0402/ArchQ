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
        pacman -Q ncmpcpp >/dev/null 2>&1 || pacman -Sy --noconfirm archlinux-keyring ncmpcpp tmux
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

### Include audio output
p0=off; h0=off
p1=off; h1=off
cat $config | grep pulse | grep -q '#' || p0=on 
cat $config | grep httpd | grep -q '#' || h0=on
output=$(dialog --stdout --title "ArchQ MPD" \
        --checklist "Include output" 7 0 0 \
        A Airport $p0 H Httpd $h0 ) || exit 1

[[ $output =~ A ]] && p1=on
[[ $output =~ H ]] && h1=on

if [[ $p1 == on ]]; then
    sed -i 's/^#.\?include_optional "mpd.d\/pulse.out"/include_optional "mpd.d\/pulse.out"/' $config
    systemctl enable --now avahi-daemon
    user=$(grep '1000' /etc/passwd | awk -F: '{print $1}')
    echo "Use command 'pulse_airport' to set Airport output device @$user."
else
    sed -i 's/^include_optional "mpd.d\/pulse.out"/#include_optional "mpd.d\/pulse.out"/' $config
fi

if [[ $h1 == on ]]; then
    sed -i 's/^#.\?include_optional "mpd.d\/httpd.out"/include_optional "mpd.d\/httpd.out"/' $config
else   
    sed -i 's/^include_optional "mpd.d\/httpd.out"/#include_optional "mpd.d\/httpd.out"/' $config
fi

systemctl restart mpd
