#!/bin/bash
serpath='/usr/lib/systemd/system/'
service=("mpd" "logitechmediaserver" "squeezelite" "shairport-sync")
nickname=("MPD" "LMS" "Squeezelite" "Airplay")
menu=''
arrList=()
for ((i=0; i < ${#service[@]}; i++))
do
    if [ -f "${serpath}${service[$i]}.service" ]; then
        menu+=$i' '${nickname[$i]}
        arrList+=(${nickname[$i]})
        arrService+=(${service[$i]})
        grep -q pagecache-management "${serpath}${service[$i]}.service" && menu+=' on ' || menu+=' off '
    fi
done

options=$(dialog --stdout --title "ArchQ $1" --checklist "Data Cache" 7 0 0 ${menu}) || exit 1; clear
for ((i=0; i < ${#arrList[@]}; i++))
do
    if ( echo $options | grep -q $i ); then
        grep -q pagecache-management "${serpath}${arrService[$i]}.service" || \
        sed -i 's|ExecStart=|ExecStart=/usr/bin/pagecache-management.sh |' "${serpath}${arrService[$i]}.service"
    else
        sed -i 's|ExecStart=/usr/bin/pagecache-management.sh |ExecStart=|' "${serpath}${arrService[$i]}.service"
    fi
done                        