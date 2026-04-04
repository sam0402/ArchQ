#!/bin/bash

config='/etc/fstab'
grub_cfg='/boot/grub/grub.cfg'

c_blue_b=$'\e[1;38;5;27m'
c_gray=$'\e[m'
cpus=$(getconf _NPROCESSORS_ONLN)

# pacman -Q ramroot >/dev/null 2>&1 || ramroot='R Ramroot'
# pacman -Q alsa-lib | grep -qE 'alsa-lib .*-1.$' \
#   && alsalib='A ALSAlib@Dynamic' \
#   || alsalib='A ALSAlib@Soft'
pacman -Q xf86-video-fbdev >/dev/null 2>&1 || alsalib='A ALSAlib'

WK=$(dialog --stdout --title "ArchQ $1" \
            --menu "Select an action:" 7 0 0 B Boot I Install M Remove $ramroot F Frequency $alsalib) || exit 1; clear

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
        exec='dialog --stdout --title "ArchQ '$1'" --menu "Select an item to install" 7 0 0 '
        while read line; do
            ver=$(echo $line | awk -F: '{print $1}')
            info=$(echo $line | awk -F: '{print $2}')
            exec+=$ver' '\"$info\"' '
        done <<< "$(curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/kernel/kver)"

        options=$(eval $exec) || exit 1; clear
        if [ -n "$options" ]; then
            echo -e "${c_blue_b}Install kernel ${options}...${c_gray}"
            wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/kernel/linux-${options}-x86_64.pkg.tar.zst
            pacman -U --noconfirm /tmp/linux-${options}-x86_64.pkg.tar.zst
        fi
        pacman -Q ramroot >/dev/null 2>&1 && ramroot -E
        rm /boot/*-fallback.img
        mkgrub
        ;;
    P)
        exec='dialog --stdout --title "ArchQ @P5801x '$1'" --menu "Select an item to install" 7 0 0 '
        while read line; do
            ver=$(echo $line | awk -F: '{print $1}')
            info=$(echo $line | awk -F: '{print $2}')
            exec+=$ver' '\"$info\"' '
        done <<< "$(curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/i5801/kver)"
        pacman -Q alsa-lib | grep -q '\-3' && ! pacman -Q xf86-video-fbdev >/dev/null 2>&1 && exec+='ALSA-lib @P5801x '
        options=$(eval $exec) || exit 1; clear
        if [ -n "$options" ]; then
            echo -e "${c_blue_b}Install kernel ${options} @P5801x ...${c_gray}"
            wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/i5801/linux-${options}-x86_64.pkg.tar.zst
            pacman -U --noconfirm /tmp/linux-${options}-x86_64.pkg.tar.zst
        fi
        rm /boot/*-fallback.img
        mkgrub
        ;;
    M)
        while read line; do
            menu+="$line "
        done <<< "$(pacman -Q | grep linux-[DQ] | grep -v headers)"
        options=$(dialog --stdout \
                --title "ArchQ $1" \
                --menu "Select a kernel to remove" 7 0 0 $menu) || exit 1; clear
        echo -e "${c_blue_b}Remove kernel ${options}...${c_gray}"
        pacman -R ${options}
        mkgrub
        ;;
    B)
        grub_def='/etc/default/grub'; n=0
        grep -q '#GRUB_DISABLE_SUBMENU' $grub_def && sed -i 's/^#\?GRUB_DISABLE_SUBMENU=.*$/GRUB_DISABLE_SUBMENU=y/' $grub_def

        bootlist='dialog --stdout --title "ArchQ $1" --menu "Select default boot" 7 0 0 '
        while read line; do
            echo $line | grep 'fallback' || bootlist+=$n' '\"$line\"' '
            ((n++))
        done <<< "$(grep 'menuentry ' $grub_cfg | cut -d "'" -f2 | sed '$d;s/Arch Linux, with Linux //;s/ initramfs//'|cut -d' ' -f1-2)"
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
        # dialog --stdout --title "ArchQ $1" --infobox "\n\n    Wait for 10 seconds..." 7 35[]
        l1=$(cat /proc/interrupts | grep tick); sleep 10; l2=$(cat /proc/interrupts | grep tick)
        count='\n'
        for (( i=2; i<=$cpus+1; i++ ))
        do
            t1=$(echo $l1 | grep tick | cut -d ' ' -f $i)
            t2=$(echo $l2 | grep tick | cut -d ' ' -f $i)
            count+="Core$((i - 2)): "
            [ -f /usr/bin/python ] && count+=$(python -c "print(round(($t2-$t1)/10000.0,1))")'\n' \
                                || count+="$((t2 / 10000 - t1 / 10000))\n"
        done
        dialog --stdout --title "ArchQ $1" --msgbox "\nKernel frequency: $count" $((cpus + 6)) 35; clear
        ;;
    A)
        a_name=(Halo Soft Analytical Dynamic)
        ver=(11 15 21 25)

        declare -A name2ver ver2name

        for i in "${!a_name[@]}"; do
            name2ver[${a_name[$i]}]=${ver[$i]}
            ver2name[${ver[$i]}]=${a_name[$i]}
        done

        inst_ver=$(pacman -Q alsa-lib | awk -F '-' '{print $3}')

        menu_items=()
        for name in "${a_name[@]}"; do
            menu_items+=("$name" "")
        done

        op=$(dialog --stdout \
            --title "ALSA-lib ${ver2name[$inst_ver]}" \
            --menu "Select version:" 7 0 0 \
            "${menu_items[@]}" )|| exit 1
        clear
        
        echo -e "${c_blue_b}Install ALSA-lib ${op}...${c_gray}"
        wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/alsa-lib-1.1.9-${name2ver[$op]}-x86_64.pkg.tar.zst
        pacman -U --noconfirm /tmp/alsa-lib-1.1.9-${name2ver[$op]}-x86_64.pkg.tar.zst

        dialog --stdout --title "ALSA-lib $1" --yesno "The ${op} is up to date. \nReboot to take effect?" 0 0 && reboot || exit 0
        clear
        ;;    
esac