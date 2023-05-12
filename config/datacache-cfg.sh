#!/bin/bash
serpath='/usr/lib/systemd/system/'
service=("mpd" "logitechmediaserver" "squeezelite" "shairport-sync" "hqplayerd" "networkaudio")
nickname=("MPD" "LMS" "Squeezelite" "Airplay" "HQPlayerEmbedded" "NAA")

arrList=(); arrService=()
for ((i=0; i < ${#service[@]}; i++))
do
    if [ -f "${serpath}${service[$i]}.service" ]; then
        arrList+=(${nickname[$i]})
        arrService+=(${service[$i]})
    fi
done

menu='';
for ((i=0; i < ${#arrList[@]}; i++))
do
    menu+=$i' '${arrList[$i]}
    grep -q pagecache-management "${serpath}${arrService[$i]}.service" && menu+=' on ' || menu+=' off '
done

options=$(dialog --stdout --title "ArchQ $1" --checklist "Data cache OFF" 7 0 0 ${menu}) || exit 1; clear
for ((i=0; i < ${#arrList[@]}; i++))
do
    if ( echo $options | grep -q $i ); then
        grep -q pagecache-management "${serpath}${arrService[$i]}.service" || \
        sed -i 's|ExecStart=|ExecStart=/usr/bin/pagecache-management.sh |' "${serpath}${arrService[$i]}.service"
    else
        sed -i 's|ExecStart=/usr/bin/pagecache-management.sh |ExecStart=|' "${serpath}${arrService[$i]}.service"
    fi
done
systemctl daemon-reload             