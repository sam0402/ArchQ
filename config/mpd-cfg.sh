#!/bin/bash
config='/etc/mpd.conf'

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

### set music direcroty

mdir=$(grep 'music_directory' $config | awk -F \" '{print $2}' | awk -F \/ '{print $3}')

mdir=$(dialog --stdout \
    --title "ArchQ MPD" \
    --ok-label "Ok" \
    --form "Music directory" 0 30 0 \
    " /mnt/"  1 1 $mdir 1 7 30 0) || exit 1
clear
grep -q '#[[:space:]]mixer_type "soft' $config && volctl=off || volctl=on
vol=$(dialog --stdout \
    --title "ArchQ MPD" \
    --checklist "Volume Control" 7 0 0 \
    E Enable $volctl ) || exit 1
clear

[ -n "$vol" ] && sed -i 's/^#.\?mixer_type.*"/\tmixer_type "software"/' $config \
              || sed -i 's/^.\?mixer_type.*"/#\tmixer_type "software"/' $config

sed -i 's/^#\?music_directory.*"/music_directory "\/mnt\/'"$mdir"'"/' $config

echo $config is setting.
systemctl restart mpd
echo MPD is restarted.