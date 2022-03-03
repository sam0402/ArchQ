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
        --title "MPD" \
        --menu "Select ouput device" 7 0 0 ${devs}) || exit 1
clear
sed -i 's/^#\? .*name.*"/    name '"\"$device\""'/' $config

### set music direcroty

mdir=$(grep 'music_directory' $config | awk -F \" '{print $2}' | awk -F \/ '{print $3}')

mdir=$(dialog --stdout \
    --title "MPD" \
    --ok-label "Ok" \
    --form "Music directory" 0 30 0 \
    " /mnt/"  1 1 $mdir 1 7 30 0) || exit 1
clear

sed -i 's/^#\?music_directory.*"/music_directory "\/mnt\/'"$mdir"'"/' $config

echo $config is setting.
systemctl restart mpd
echo MPD is restarted.