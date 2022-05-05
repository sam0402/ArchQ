#!/bin/bash
config='/etc/fstab'
WK=$(dialog --stdout --title "ArchQ $1" \
            --menu "Select command" 7 0 0 B "Boot" I "Install" R "Remove" F "Frequency") || exit 1
clear
case $WK in
    I)
        exec='dialog --stdout --title "ArchQ '$1'" --menu "Select to install" 7 0 0 '
        while read line; do
            ver=$(echo $line | awk -F: '{print $1}')
            info=$(echo $line | awk -F: '{print $2}')
            exec+=$ver' '\"$info\"' '
        done <<< $(curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/kernel/kver)
        options=$(eval $exec) || exit 1
        clear

        if [ -n $options ]; then
            ver=$(echo $options | cut -d '-' -f 1)
            kver=$(echo $options | cut -d '-' -f 2-3)
            echo "Install Kernel ${ver}-${kver}..."
            [ ! -f "/root/linux-${ver}-${kver}-x86_64.pkg.tar.zst" ] && wget -P /root https://raw.githubusercontent.com/sam0402/ArchQ/main/kernel/linux-${ver}-${kver}-x86_64.pkg.tar.zst
            pacman -U --noconfirm /root/linux-${ver}-${kver}-x86_64.pkg.tar.zst
        fi
        grub-mkconfig -o /boot/grub/grub.cfg
        ;;
    R)
        while read line; do
            menu+=${line}' '
        done <<< $(pacman -Q | grep linux-Q | grep -v headers)
        options=$(dialog --stdout \
                --title "ArchQ $1" \
                --menu "Select to remove" 7 0 0 $menu) || exit 1
        clear
        echo Rmove Kernel Q1xx ...
        pacman -R ${options}
        grub-mkconfig -o /boot/grub/grub.cfg
        ;;
    B)
        grub_def='/etc/default/grub'
        if [ -n "$(grep '#GRUB_DISABLE_SUBMENU' $grub_def)" ]; then 
            sed -i 's/^#\?GRUB_DISABLE_SUBMENU=.*$/GRUB_DISABLE_SUBMENU=y/' $grub_def
            grub-mkconfig -o /boot/grub/grub.cfg
        fi
        n=0; menu=''
        while read line; do
            menu+=${n}' '${line}' '
            n=`expr $n + 2`
        done <<< $(grep 'with' /boot/grub/grub.cfg | grep -v 'fallback' | cut -d "'" -f2 | cut -d ' ' -f5)
        options=$(dialog --stdout \
                --title "ArchQ $1" \
                --menu "Select default boot" 7 0 0 $menu S "Save Default") || exit 1
        clear
        [ $options = 'S' ] && sed -e 's/^#\?GRUB_SAVEDEFAULT=.*$/GRUB_SAVEDEFAULT=true/' $grub_def
        sed -i 's/^#\?GRUB_DEFAULT=.*$/GRUB_DEFAULT='"$options"'/' $grub_def
        grub-mkconfig -o /boot/grub/grub.cfg
        ;;
    F)
        cpus=2
        num=`expr $cpus + 1`
        cmd="cat /proc/interrupts | grep tick | awk '{print \$${num}}'"
        echo "Wait for 10 seconds..."
        t1=$(eval $cmd)
        sleep 10
        t2=$(eval $cmd)
        count=$(expr $t2 / 10000 - $t1 / 10000)
        echo "Kernel working frequency: $count"
        ;;
esac