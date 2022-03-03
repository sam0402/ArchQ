#!/bin/bash
[ -f /root/.update ] || echo 0 >/root/.update
num=$(cat /root/.update)
git=$(curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/update)

MENU=''
[ -f /etc/mpd.conf ] && MENU='D MPD '
[ -f /etc/squeezelite.conf ] && MENU+='S Squeezelite '
[ -f /etc/shairport-sync.conf ] && MENU+='A Airplay '
[ $git -gt $num ] && MENU+='U Update '

WK=$(dialog --stdout --title "ArchQ" \
    --menu "Select to config" 7 0 0 K Kernel M "Partition mount" N "NFS mount" \
        E Ethernet T Timezone P "Active Player" ${MENU}) || exit 1
clear
case $WK in
    K)
        /usr/bin/kernel-cfg.sh
        ;;
    M)
        /usr/bin/partimnt-cfg.sh
        ;;
    N)
        /usr/bin/nfs-cfg.sh
        ;;
    D)
        /usr/bin/mpd-cfg.sh
        ;;
    P)
        /usr/bin/player-cfg.sh
        ;;
    E)
        /usr/bin/ether-cfg.sh
        ;;
    S)
        /usr/bin/sqzlite-cfg.sh
        ;;
    A)
        /usr/bin/shairport-cfg.sh
        ;;
    T)
        /usr/bin/timezone.sh
        ;;
    U)
        curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/update_scpt.sh >/usr/bin/update_scpt.sh
        chmod +x /usr/bin/update_scpt.sh
        /usr/bin/update_scpt.sh
        echo $git >/root/.update
        ;;
esac