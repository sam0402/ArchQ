#!/bin/bash
[ -f /root/.update ] || echo 0 >/root/.update
num=$(cat /root/.update)
git=$(curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/update)

Qver=$(uname -r | awk -F - '{print $3}')
temp=$(sensors | grep 'Core 0' | awk '{print $3}')

MENU=''
pacman -Q mpd >/dev/null 2>&1 && MENU='D MPD '
pacman -Q squeezelite >/dev/null 2>&1 && MENU+='S Squeezelite '
pacman -Q shairport-sync >/dev/null 2>&1 && MENU+='A Airplay '
#pacman -Q ffmpeg >/dev/null 2>&1 && MENU+='F FFmpeg '
[ $git -gt $num ] && MENU+='U Update '

WK=$(dialog --stdout --title "ArchQ $Qver   $temp" \
    --menu "Select to config" 7 0 0 K Kernel M "Partition mount" N "NFS mount" B "SMB/CIFS mount" \
        E Ethernet T Timezone X "Desktop & VNC" P "Active player" R "abCDe ripper" C "CPU frequency" ${MENU}) || exit 1
clear
case $WK in
    K)
        /usr/bin/kernel-cfg.sh $Qver
        ;;
    M)
        /usr/bin/partimnt-cfg.sh $Qver
        ;;
    N)
        /usr/bin/nfs-cfg.sh $Qver
        ;;
    B)
        /usr/bin/smb-cfg.sh $Qver
        ;;
    D)
        /usr/bin/mpd-cfg.sh $Qver
        ;;
    P)
        /usr/bin/player-cfg.sh $Qver
        ;;
    E)
        /usr/bin/ether-cfg.sh $Qver
        ;;
    S)
        /usr/bin/sqzlite-cfg.sh $Qver
        ;;
    A)
        /usr/bin/shairport-cfg.sh $Qver
        ;;
    X)
        /usr/bin/desktop-cfg.sh $Qver
        ;;
    R)
        /usr/bin/abcde-cfg.sh $Qver
        ;;
    C)
        /usr/bin/cpu-cfg.sh $Qver
        ;;
    T)
        /usr/bin/timezone.sh $Qver
        ;;
    F)
        pacman -Q ffmpeg | grep -q '\-12' && ff=on || ff=off
        ffen=$(dialog --stdout \
            --title "ArchQ $Qver   $temp" \
            --checklist "Use ArchQ FFmpeg" 7 0 0 \
            E Enable $ff ) || exit 1
        if [ $ffen == 'E' ]; then
            wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/ffmpeg-2%3A5.1.2-12-x86_64.pkg.tar.zst
            pacman -U --noconfirm /root/ffmpeg-2:5.1.2-12-x86_64.pkg.tar.zst
        else
            pacman -S --noconfirm ffmpeg
        fi
        ;;
    U)
        curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/update_scpt.sh >/usr/bin/update_scpt.sh
        chmod +x /usr/bin/update_scpt.sh
        /usr/bin/update_scpt.sh
        echo $git >/root/.update
        ;;
    H)
        pacman -Sy --noconfirm archlinux-keyring
        pacman -Scc --noconfirm
        pacman -Syy --noconfirm
        pacman -Syu --noconfirm
        [ -f /root/alsa-lib-1.1.9-2-x86_64.pkg.tar.zst ] || wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/alsa-lib-1.1.9-2-x86_64.pkg.tar.zst
        pacman -R --noconfirm alsa-utils
        pacman -U --noconfirm --overwrite '*' /root/alsa-lib-1.1.9-2-x86_64.pkg.tar.zst
        pacman -Sd --noconfirm alsa-utils
        ;;
esac
