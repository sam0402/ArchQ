#!/bin/bash
config='/etc/mpd.conf'

### Music direcroty
mdir=$(grep 'music_directory' $config | awk -F \" '{print $2}' | awk -F \/ '{print $3}')

mdir=$(dialog --stdout \
    --title "ArchQ MPD" \
    --ok-label "Ok" \
    --form "Music directory" 0 30 0 \
    " /mnt/"  1 1 $mdir 1 7 30 0) || exit 1
clear
sed -i 's/^#\?music_directory.*"/music_directory "\/mnt\/'"$mdir"'"/' $config

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
        sed -i 's/type "pulse"/type "alsa"/' $config
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
        sed -i 's/^#\?.* \?\tdevice.*"/\tdevice '"\"$device\""'/' $config

        ### Volume Control
        grep -q '#[[:space:]]mixer_type "soft' $config && volctl=off || volctl=on
        vol=$(dialog --stdout \
            --title "ArchQ MPD" \
            --checklist "Volume Control" 7 0 0 \
            E Enable $volctl ) || exit 1
        clear

        [ -n "$vol" ] && sed -i 's/^#.\?mixer_type.*"/\tmixer_type "software"/' $config \
                    || sed -i 's/^.\?mixer_type.*"/#\tmixer_type "software"/' $config
    ;;
    A)
        sed -i 's/type "alsa"/type "pulse"/' $config
        user=$(grep '1000' /etc/passwd | awk -F: '{print $1}')
        echo "Use command 'pulse_airport' to set Airport output device @$user."
    ;;
esac

systemctl restart mpd
