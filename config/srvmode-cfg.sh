#!/bin/bash
config='/etc/srvmode.conf'
grub_cfg='/boot/grub/grub.cfg'
[ ! -s "$config" ] && echo "Active=" >$config
MENU=''; SRV='avahi-daemon mpd.socket '
pacman -Q mpd >/dev/null 2>&1 && MENU='MPD 　 off ' && SRV+='mpd '
pacman -Q rompr >/dev/null 2>&1 && MENU='Rompr 　 off '&& SRV+='mpd rompr nginx php-fpm '
pacman -Q mympd >/dev/null 2>&1 && MENU='MyMPD 　 off ' && SRV+='mpd mympd '
pacman -Q logitechmediaserver >/dev/null 2>&1 && MENU+='LMS 　 off ' && SRV+='logitechmediaserver '
pacman -Q squeezelite >/dev/null 2>&1 && MENU+='Squeezelite 　 off ' && SRV+='squeezelite '
[ -f /usr/lib/systemd/system/roonserver.service ] && MENU+='Roon 　 off ' && SRV+='roonserver '
[ -f /usr/lib/systemd/system/hqplayerd.service ] && MENU+='HQPlayerd 　 off ' && SRV+='hqplayerd '
pacman -Q roonbridge >/dev/null 2>&1 && MENU+='Roonbridge 　 off ' && SRV+='roonbridge '
pacman -Q shairport-sync >/dev/null 2>&1 && MENU+='Airplay 　 off ' && SRV+='nqptp shairport-sync '
pacman -Q hqplayer-network-audio-daemon >/dev/null 2>&1 && MENU+='"HQPlayer NAA" 　 off ' && SRV+='networkaudio '
pacman -Q owntone >/dev/null 2>&1 && MENU+='Owntone 　 off ' && SRV+='owntone '

kernel(){
    n=1; kernel=()
    while read line; do
        kernel[$n]=${line}
        ((n += 1 ))
    done <<< $(grep 'menuentry ' $grub_cfg | cut -d "'" -f2 | sed '$d;s/Arch Linux, with Linux //;s/ initramfs//'|cut -d' ' -f1-2)

    if [ ! $1 ]; then
        for i in ${!kernel[@]}; do
            $(echo ${kernel[i]} | grep -qv 'fallback') && KMENU+=$i' '${kernel[i]}' '
            (( n += 1 ))
        done
        kerboot=$(dialog --stdout --title "Service mode"  --menu "Boot Kernel" 7 0 0 $KMENU) || exit 1; clear
    fi
}

disablesrv(){
    for i in $SRV; do
        [ $(systemctl status $i 2>&1 | grep -c 'active') = 1 ] && systemctl disable $i
    done
}

stopsrv(){
    for i in $SRV; do
        [ $(systemctl status $i 2>&1 | grep -c 'enabled') = 1 ] && systemctl stop $i
    done
}

if [ "$1" == 'stopsrv' ]; then
    stopsrv
else
    WK=$(dialog --stdout --title "ArchQ $1" --menu "Service mode" 7 0 0 A Add M Modify R Remove C Active D Disable) || exit 1; clear

    case $WK in
        A)
            m_name=$(dialog --stdout --title "ArchQ $1" --ok-label "Ok" \
                --form "Add service mode" 0 30 0 "Name" 1 1  ""  1 6 30 0) || exit 1; clear
            exec='dialog --stdout --title "'$m_name'" --checklist "Select service" 7 0 0 '$MENU
            options=$(eval $exec) || exit 1; clear
            kernel
            echo "$m_name:$options:$kerboot" >>$config
            echo "Service mode $m_name add."
            ;;
        M)
            while read line; do
                e_menu+=\"$(echo $line | awk -F: '{print $1}')\"' 　 '
            done <<< $(cat $config | sed '1d')
            exec='dialog --stdout --title "ArchQ $1" --menu "Modify service mode" 7 0 0 '$e_menu
            m_name=$(eval $exec) || exit 1; clear
            for list in $(grep $m_name $config | awk -F: '{print $2}'); do
                MENU=$(echo $MENU | sed -e 's/'"$list"' 　 off /'"$list"' 　 on /')
            done
            exec='dialog --stdout --title "'$m_name'" --checklist "Select service" 7 0 0 '$MENU
            options=$(eval $exec) || exit 1; clear
            kernel
            sed -i '2,$s/'"$m_name"':.*/'"$m_name"':'"$options"':'"$kerboot"'/' $config
            echo "Service mode $m_name modify."
            ;;
        R)
            while read line; do
                e_menu+=\"$(echo $line | awk -F: '{print $1}')\"' 　 '
            done <<< $(cat $config | sed '1d')
            exec='dialog --stdout --title "ArchQ $1" --menu "Remove service mode" 7 0 0 '$e_menu
            m_name=$(eval $exec) || exit 1; clear
            sed -i '/'"$m_name"':/d' $config
            echo "Service mode $m_name remove."
            ;;
        C)
            i=1
            while read line; do
                e_menu+=$i' '\"$(echo $line | awk -F: '{print $1}')\"' '
                $((i++))
            done <<< $(cat $config | sed '1d')
            exec='dialog --stdout --title "ArchQ $1" --menu "Active service mode" 7 0 0 '$e_menu
            options=$(eval $exec) || exit 1; clear
            line=$((options+1))
            m_name=$(sed "${line}q;d" $config | awk -F: '{print $1}')
            sed -i '1s/Active=.*/Active='"$m_name"'/' $config
            disablesrv
            mboot $options
            ;;
        D)
            sed -i '1s/Active=.*/Active=/' $config
            echo "ArchQ service mode is disabled."
            ;;
    esac
fi
