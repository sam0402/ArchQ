#!/bin/bash
[ -f /root/.update ] || echo 0 >/root/.update
num=$(cat /root/.update)
gitupd=$(curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/update)

temp=$(sensors | grep 'Core 0' | awk '{print $3}')
ipaddr=$(ip -o addr | grep en | awk 'NR == 1 {print $4}')
MENU=''
[ $gitupd -gt $num ] && MENU+='U Update '
pacman -Q mpd-light >/dev/null 2>&1 && MENU+='D MPD '
pacman -Q mpd-stream >/dev/null 2>&1 && MENU+='D MPD ' 
pacman -Q mpd-ffmpeg >/dev/null 2>&1 && MENU+='D MPD ' 
pacman -Q squeezelite >/dev/null 2>&1 && MENU+='S Squeezelite '
pacman -Q shairport-sync >/dev/null 2>&1 && MENU+='A Airplay '

if [ -f /root/.advence ]; then
   MENU2='R "abCDe ripper" P Player O Server I "Service mode" J "Sync backup" G "Data cache" C "CPU frequency" Z "Zero Wipe" N "NFS mount" B "SMB/CIFS mount" V "NFS Server" E Network Y Bcache T Timezone '
	find /dev/disk/by-id/usb-* | grep -q 'usb' && MENU2+='W "HDD Poweroff" '
	if pacman -Q ffmpeg >/dev/null 2>&1; then
    [[ $(pacman -Q ffmpeg) != 'ffmpeg 2:5.1.2-12' ]] || [[ -d '/opt/RoonServer' ]] && MENU2+='F FFmpeg '
	fi
fi
[ -f /root/.advence ] && MENU2+='0 "Basic config" ' || MENU2+='1 "Advence config" '
uname -r | grep -q D && MENU2='X Desktop C "CPU frequency" T Timezone '

exec='dialog --stdout --title "'$ipaddr'  '$temp'" --menu "'$HOSTNAME'.local  Config" 7 0 0 '$MENU'K Kernel M "Partition mount" '$MENU2

options=$(eval $exec) || exit 1; clear
case $options in
	0)
        rm /root/.advence; /usr/bin/config
        ;;
	1)
        touch /root/.advence; /usr/bin/config
        ;;
    A)
        /usr/bin/shairport-cfg.sh $Qver
        ;;
    B)
        /usr/bin/smb-cfg.sh $Qver
        ;;
    C)
        /usr/bin/cpu-cfg.sh $Qver
        ;;
    D)
        /usr/bin/mpd-cfg.sh $Qver
        ;;
    E)
        /usr/bin/ether-cfg.sh $Qver
        ;;
    F)
        pacman -Q ffmpeg | grep -q '\-12' && ff=on || ff=off
        ffen=$(dialog --stdout \
            --title "ArchQ $Qver   $temp" \
            --checklist "Use ArchQ FFmpeg" 7 0 0 \
            E Enable $ff ) || exit 1; clear
        if [ $ffen == 'E' ]; then
            wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/ffmpeg-2%3A5.1.2-12-x86_64.pkg.tar.zst
            pacman -U --noconfirm /root/ffmpeg-2:5.1.12-12-x86_64.pkg.tar.zst
        else
            pacman -S --noconfirm ffmpeg
        fi
        ;;
    G)
        /usr/bin/datacache-cfg.sh $Qver
        ;;
    H)
        # pacman -Sy --noconfirm archlinux-keyring
        # pacman -Scc --noconfirm
        # pacman -Syy --noconfirm
        # pacman -Syu --noconfirm
        ;;
    I)
        /usr/bin/srvmode-cfg.sh $Qver
        ;;
    J)
        /usr/bin/sync_backup-cfg.sh $Qver
        ;;
    K)
        /usr/bin/kernel-cfg.sh $Qver
        ;;
    M)
        /usr/bin/partimnt-cfg.sh $Qver
        ;;
    N)
        /usr/bin/nfs-cfg.sh $Qver
        ;;
    O)
        /usr/bin/server-cfg.sh $Qver
        ;;
    P)
        /usr/bin/player-cfg.sh $Qver
        ;;
    R)
        /usr/bin/abcde-cfg.sh $Qver
        ;;
    S)
        /usr/bin/sqzlite-cfg.sh $Qver
        ;;
    T)
        /usr/bin/timezone.sh $Qver
        ;;
    U)
        curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/update_scpt.sh >/usr/bin/update_scpt.sh
        chmod +x /usr/bin/update_scpt.sh
        /usr/bin/update_scpt.sh
        echo $git >/root/.update
        ;;
    V)
        /usr/bin/nfserver-cfg.sh $Qver
        ;;
    W)
        /usr/bin/hddpower-cfg.sh $Qver
        ;;
    X)
        /usr/bin/desktop-cfg.sh $Qver
        ;;
    Y)
        /usr/bin/bcache-cfg.sh $Qver
        ;;
    Z)
        /usr/bin/zerowipe.sh $Qver
        ;;
esac
