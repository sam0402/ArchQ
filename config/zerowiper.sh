#!/bin/bash
config='/etc/fstab'
WK=$(dialog --stdout --title "ArchQ $1" \
            --menu "HDD Zero Wiper" 7 0 0 W "Wipe disk" F "Format XFS")
clear
case $WK in
    W)
        if ! pacman -Q scrub >/dev/null 2>&1; then
            wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/scrub-2.6.1-1-x86_64.pkg.tar.zst
            pacman -U --noconfirm /root/scrub-2.6.1-1-x86_64.pkg.tar.zst
        fi
        devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | grep sd | tac)
        device=$(dialog --stdout --title "Wipe disk" --menu "Select HDD device" 7 0 0 $devicelist) || exit 1
        clear
        partitionlist=$(lsblk -pln -o name,size $device | sed -e '1d;s/\s\+/ /g')
        partition=$(dialog --stdout --title "Device $device" --menu "Select partition" 7 0 0 $partitionlist) || exit 1
        times=$(dialog --stdout \
            --title "Partition $(echo $partition|cut -d/ -f3)" \
            --inputbox "Wipe times (6GB/min)" 0 25 1) || exit 1
        
        for ((i=0; i < $times; i++))
        do
            scrub -fp fillzero $partition
        done
        ;;
    F)
        devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | grep sd | tac)
        device=$(dialog --stdout --title "Format disk" --menu "Select HDD device" 7 0 0 $devicelist) || exit 1
        clear
        partitionlist=$(lsblk -pln -o name,size $device | sed -e '1d;s/\s\+/ /g')
        partition=$(dialog --stdout --title "Device $device" --menu "Select partition" 7 0 0 $partitionlist) || exit 1
        yes1=$(dialog --stdout --title "Format" --yesno "Partition $(echo $partition|cut -d/ -f3) to XFS" 0 0) || exit 1
        yes2=$(dialog --stdout --title "Format XFS" --yesno "Format $(echo $partition|cut -d/ -f3) conform" 0 0) || exit 1
        [[ $yes1] && [$yes2 ]] && mkfs.xfs $partition
        ;;
esac
