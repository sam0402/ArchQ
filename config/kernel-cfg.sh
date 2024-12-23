#!/bin/bash
config='/etc/fstab'
grub_cfg='/boot/grub/grub.cfg'
pacman -Q ramroot >/dev/null 2>&1 || ramroot='R Ramroot'
WK=$(dialog --stdout --title "ArchQ $1" \
            --menu "Select command" 7 0 0 B Boot I Install M Remove $ramroot F Frequency) || exit 1; clear

mkgrub(){
    if lsblk -pln -o name,partlabel | grep -q Microsoft; then
        part_boot=$(lsblk -pln -o name,parttypename | grep EFI | awk 'NR==1 {print $1}')
        mount "$part_boot" /mnt
        sleep 2
        os-prober | grep -q Windows || umount /mnt
    fi
    grub-mkconfig -o $grub_cfg
    pacman -Q ramroot >/dev/null 2>&1 && sed -i 's/fallback/ramroot/g' $grub_cfg
}

case $WK in
    I)
        exec='dialog --stdout --title "ArchQ '$1'" --menu "Select to install" 7 0 0 '
        while read line; do
            ver=$(echo $line | awk -F: '{print $1}')
            info=$(echo $line | awk -F: '{print $2}')
            exec+=$ver' '\"$info\"' '
        done <<< $(curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/kernel/kver)
        options=$(eval $exec) || exit 1; clear

        if [ -n $options ]; then
            ver=$(echo $options | cut -d '-' -f 1)
            kver=$(echo $options | cut -d '-' -f 2-3)
            echo "Install Kernel ${ver}-${kver}..."
            wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/kernel/linux-${ver}-${kver}-x86_64.pkg.tar.zst
            pacman -U --noconfirm /tmp/linux-${ver}-${kver}-x86_64.pkg.tar.zst
        fi
        pacman -Q ramroot >/dev/null 2>&1 && ramroot -E
        rm /boot/*-fallback.img
        mkgrub
        ;;
    M)
        while read line; do
            menu+=${line}' '
        done <<< $(pacman -Q | grep linux-[DQ] | grep -v headers)
        options=$(dialog --stdout \
                --title "ArchQ $1" \
                --menu "Select to remove" 7 0 0 $menu) || exit 1; clear
        echo Rmove Kernel Q1xx ...
        pacman -R ${options}
        mkgrub
        ;;
    B)
        grub_def='/etc/default/grub'; n=0
        grep -q '#GRUB_DISABLE_SUBMENU' $grub_def && sed -i 's/^#\?GRUB_DISABLE_SUBMENU=.*$/GRUB_DISABLE_SUBMENU=y/' $grub_def

        bootlist='dialog --stdout --title "ArchQ $1" --menu "Select default boot" 7 0 0 '
        while read line; do
            echo $line | grep 'fallback' || bootlist+=$n' '\"$line\"' '
            n=`expr $n + 1`
        done <<< $(grep 'menuentry ' $grub_cfg | cut -d "'" -f2 | sed '$d;s/Arch Linux, with Linux //;s/ initramfs//'|cut -d' ' -f1-2)
        bootlist+='S "Save Default"'
        options=$(eval $bootlist) || exit 1; clear

        sed -i 's/^#\?GRUB_DEFAULT=.*$/GRUB_DEFAULT='"$options"'/' $grub_def
        [ $options = 'S' ] && sed -i 's/^#\?GRUB_SAVEDEFAULT=.*$/GRUB_SAVEDEFAULT=true/' $grub_def
        mkgrub
        ;;
    R)
        wget -qP /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/ramroot-2.0.2-2-x86_64.pkg.tar.zst
        pacman -U --noconfirm /tmp/ramroot-2.0.2-2-x86_64.pkg.tar.zst
        pacman -Scc --noconfirm >/dev/null 2>&1
        mkgrub
        ;;
    F)
        dialog --stdout --title "ArchQ $1" --infobox "\n\n    Wait for 10 seconds..." 7 35
        cpus=$(getconf _NPROCESSORS_ONLN)
        l1=$(cat /proc/interrupts | grep tick); sleep 10; l2=$(cat /proc/interrupts | grep tick)
        count='\n'
        for (( i=2; i<=$cpus+1; i++ ))
        do
            t1=$(echo $l1 | grep tick | cut -d ' ' -f $i)
            t2=$(echo $l2 | grep tick | cut -d ' ' -f $i)
            count+='Core'$(expr $i - 2)': '
            [ -f /usr/bin/python ] && count+=$(python -c "print(round(($t2-$t1)/10000.0),1)" | sed 's/ /./')'\n' \
                                || count+=$(expr $t2 / 10000 - $t1 / 10000)'\n'
        done
        dialog --stdout --title "ArchQ $1" --msgbox "\nKernel working frequency: $count" $(expr $cpus + 6) 35; clear
        ;;
esac
