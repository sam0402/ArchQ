#!/bin/bash
file='/usr/lib/systemd/system-shutdown/hdd-poweroff'
arrDev=()
MENU=''; i=0
while read line; do
    arrDev+=($line)
    MENU=${MENU}' '$i' '$(echo $line | cut -d '_' -f1-2)
    ((++i))
    grep -q "$line" "$file" && MENU=${MENU}' on ' || MENU=${MENU}' off ' 
done <<< $(ls /dev/disk/by-id/usb-* | grep -v 'part' | cut -d '/' -f5)

options=$(dialog --stdout \
        --title "HDD poweroff" \
        --checklist "Select device" 7 0 0 $MENU) || exit 1; clear

echo '#!/bin/sh' >$file
for i in $options
do  
    echo '[ "$1" = "poweroff" ] && /usr/bin/hdparm -f -F -Y /dev/disk/by-id/'${arrDev[$i]} >>$file
done
chmod +x $file
