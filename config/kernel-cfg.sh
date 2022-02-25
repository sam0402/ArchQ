#!/bin/bash
config='/etc/fstab'
WK=$(dialog --stdout --title "ArchQ Kernel" \
            --menu "Select command" 7 0 0 B "Boot" U "Update" R "Remove") || exit 1
clear
case $WK in
    U)
        exec='dialog --stdout --title "ArchQ Kernel" --menu "Select to update" 7 0 0 '
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
            echo Install Kernel Q176 ...
            [ ! -f "/root/linux-${ver}-${kver}-x86_64.pkg.tar.zst" ] && wget -P /root https://raw.githubusercontent.com/sam0402/ArchQ/main/kernel/linux-${ver}-${kver}-x86_64.pkg.tar.zst
            [ ! -f "/root/linux-${ver}-headers-${kver}-x86_64.pkg.tar.zst" ] && wget -P /root https://raw.githubusercontent.com/sam0402/ArchQ/main/kernel/linux-${ver}-headers-${kver}-x86_64.pkg.tar.zst
            pacman -U --noconfirm /root/linux-${ver}-${kver}-x86_64.pkg.tar.zst /root/linux-${ver}-headers-${kver}-x86_64.pkg.tar.zst
        fi
        ;;
    R)
        while read line; do
            menu+=${line}' '
        done <<< $(pacman -Q | grep linux-Q | grep -v headers)
        options=$(dialog --stdout \
                --title "ArchQ Kernel" \
                --menu "Select to remove" 7 0 0 $menu) || exit 1
        clear
        echo Rmove Kernel Q1xx ...
        pacman -R ${options} ${options}-headers
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
                --title "ArchQ Kernel" \
                --menu "Select default boot" 7 0 0 $menu S "Save Default") || exit 1
        clear
        [ $options = 'S' ] && sed -e 's/^#\?GRUB_SAVEDEFAULT=.*$/GRUB_SAVEDEFAULT=true/' $grub_def
        sed -i 's/^#\?GRUB_DEFAULT=.*$/GRUB_DEFAULT='"$options"'/' $grub_def
        ;;
esac
grub-mkconfig -o /boot/grub/grub.cfg
