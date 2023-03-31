#!/bin/bash
config='/etc/fstab'
grub_cfg='/boot/grub/grub.cfg'
WK=$(dialog --stdout --title "ArchQ $1" \
            --menu "Select command" 7 0 0 B "Boot" I "Install" R "Remove" F "Frequency") || exit 1; clear
part_boot=$(lsblk -pln -o name,parttypename | grep EFI | awk 'NR==1 {print $1}')
mount "$part_boot" /mnt
sleep 1
os-prober
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
        grub-mkconfig -o $grub_cfg
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
        grub-mkconfig -o $grub_cfg
        ;;
    B)
        grub_def='/etc/default/grub'
        if [ -n "$(grep '#GRUB_DISABLE_SUBMENU' $grub_def)" ]; then 
            sed -i 's/^#\?GRUB_DISABLE_SUBMENU=.*$/GRUB_DISABLE_SUBMENU=y/' $grub_def
            grub-mkconfig -o $grub_cfg
        fi
        n=0
        bootlist='dialog --stdout --title "ArchQ $1" --menu "Select default boot" 7 0 0 '
        while read line; do
            echo $line | grep 'fallback' || bootlist+=$n' '\"$line\"' '
            n=`expr $n + 1`
        done <<< $(grep 'menuentry ' $grub_cfg | cut -d "'" -f2 | sed '$d;s/Arch Linux, with Linux //;s/ initramfs//'|cut -d' ' -f1-2)
        options=$(eval $bootlist) || exit 1; clear

        [ $options = 'S' ] && sed -e 's/^#\?GRUB_SAVEDEFAULT=.*$/GRUB_SAVEDEFAULT=true/' $grub_def
        sed -i 's/^#\?GRUB_DEFAULT=.*$/GRUB_DEFAULT='"$options"'/' $grub_def
        grub-mkconfig -o $grub_cfg
        ;;
    F)
        num=$(getconf _NPROCESSORS_ONLN)
        cmd="cat /proc/interrupts | grep tick | awk '{print \$${num}}'"
        dialog --stdout --title "ArchQ $1" --infobox "\n\n    Wait for 10 seconds..." 7 35
        t1=$(eval $cmd); sleep 10; t2=$(eval $cmd)
        [ -f /usr/bin/python ] && count=$(python -c "print(round(($t2-$t1)/10000.0),1)" | sed 's/ /./') || \
        count=$(expr $t2 / 10000 - $t1 / 10000)
        dialog --stdout --title "ArchQ $1" --msgbox "\nKernel working frequency: $count" 7 35
        ;;
esac
umount /mnt