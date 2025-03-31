#!/bin/bash
current=$(cpupower frequency-info | grep "current CPU" | awk '{print $4$5}')
available=$(cpupower frequency-info | grep 'steps' | cut -d' ' -f7- | sed 's/ G/G/g;s/ M/M/g')

if [[ $current =~ "Unableto" ]]; then
    dialog --stdout --title "ArchQ $1" --msgbox "\n  The Intel SpeedStep setting is disabled and \n  unavailable for adjusting the CPU frequency." 8 45
else
    # fan=$(sensors | grep 'RPM' | awk '{print "\n\n"$1,$2,$3,$4}')
    msg="Frequency available:\n$available"

    freq=$(dialog --stdout --title "ArchQ $1 $current" \
                --inputbox "$msg" 0 0 "$current") || exit 1; clear

    sed -i 's/^#\?freq=.*/freq="'"$freq"'"/' /etc/default/cpupower
    cpupower frequency-set -f $freq >/dev/null

    i=0
    while read line; do
        i=$(($i+1))
        echo "Core$i: ${line} MHz"
    done <<< $(cat /proc/cpuinfo | grep MHz | cut -d: -f2)
fi
