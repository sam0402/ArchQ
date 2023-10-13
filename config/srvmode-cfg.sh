#!/bin/bash
config='/etc/srvmenu.conf'
grub_cfg='/boot/grub/grub.cfg'
[ ! -f "$config" ] && echo "Active=" >$config
MENU=''; SRV='avahi-daemon mpd.socket '
MPD=''
pacman -Q mpd >/dev/null 2>&1 && MPD='MPD 　 on ' && SRV+='mpd '
pacman -Q mympd >/dev/null 2>&1 && MPD='MyMPD 　 on ' && SRV+='mpd mympd '
pacman -Q rompr >/dev/null 2>&1 && MPD='Rompr 　 on '&& SRV+='mpd rompr nginx php-fpm '
MENU+=$MPD
pacman -Q logitechmediaserver >/dev/null 2>&1 && MENU+='LMS 　 on ' && SRV+='logitechmediaserver '
pacman -Q squeezelite >/dev/null 2>&1 && MENU+='Squeezelite 　 on ' && SRV+='squeezelite '
[ -f /usr/lib/systemd/system/roonserver.service ] && MENU+='Roon 　 on ' && SRV+='roonserver '
[ -f /usr/lib/systemd/system/hqplayerd.service ] && MENU+='HQPlayerd 　 on ' && SRV+='hqplayerd '
pacman -Q roonbridge >/dev/null 2>&1 && MENU+='Roonbridge 　 on ' && SRV+='roonbridge '
pacman -Q shairport-sync >/dev/null 2>&1 && MENU+='Airplay 　 on ' && SRV+='shairport-sync '
pacman -Q hqplayer-network-audio-daemon >/dev/null 2>&1 && MENU+='"HQPlayer NAA" 　 on ' && SRV+='networkaudio '
pacman -Q owntone >/dev/null 2>&1 && MENU+='Owntone 　 on ' && SRV+='owntone '

kernel(){
    n=1; kernel=()
    while read line; do
        kernel[$n]=${line}
        ((n += 1 ))
    done <<< $(grep 'menuentry ' $grub_cfg | cut -d "'" -f2 | sed '$d;s/Arch Linux, with Linux //;s/ initramfs//'|cut -d' ' -f1-2)
    input=$1
    if [ ! $1 ]; then
        for i in ${!kernel[@]}; do
            $(echo ${kernel[i]} | grep -qv 'fallback') && KMENU+=$i' '${kernel[i]}' '
            (( n += 1 ))
        done
        kerboot=$(dialog --stdout --title "Service mode"  --menu "Boot Kernel" 7 0 0 $KMENU) || exit 1; clear
    fi
}

stopsrv(){
    for i in $SRV; do
        :
        # [ $(systemctl status $i 2>&1 | grep -c 'Started') = 1 ] && systemctl disable $i 
    done
}

if [ "$1" == 'stopsrv' ]; then
    stopsrv
else
    WK=$(dialog --stdout --title "ArchQ $1" --menu "Service mode" 7 0 0 A Add M Modify R Remove C Active) || exit 1; clear

    case $WK in
        A)
            m_name=$(dialog --stdout --title "ArchQ $1" --ok-label "Ok" \
                --form "Add service mode" 0 30 0 "Name" 1 1  ""  1 6 30 0) || exit 1; clear
            exec='dialog --stdout --title "'$m_name'" --checklist "Select service" 7 0 0 '$MENU
            options=$(eval $exec) || exit 1; clear
            kernel
            # service=$(echo $options | sed -e 's/\(.*\)/\L\1/;s/lms/logitechmediaserver/;s/"hqplayer naa"/naa/;s/owntone/mtroom/;')
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
                MENU=$(echo $MENU | sed -e 's/'"$list"' 　 0on /'"$list"' 　 off /')
            done
            exec='dialog --stdout --title "'$m_name'" --checklist "Select service" 7 0 0 '$MENU
            options=$(eval $exec) || exit 1; clear
            kernel
            sed -e '2,$s/'"$m_name"':.*/'"$m_name"':'"$options"':'"$kerboot"'/' $config
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
            optine=$(eval $exec) || exit 1; clear
            line=$((optine+1))
            m_name=$(sed "${line}q;d" $config | awk -F: '{print $1}')
            sed -i '1s/Active=.*/Active='"$m_name"'/' $config
            stopsrv
            ./mboot $optine
            ;;
    esac
fi
