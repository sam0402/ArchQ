#!/bin/bash
config='/etc/fstab'
WK=$(dialog --stdout --title "ArchQ $1" \
            --menu " !!! HDD Zero Wipe !!! \n Will clean device data!" 8 0 0 W "Wipe disk" F "Format XFS")
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
        clear
        times=$(dialog --stdout \
            --title "Wipe $(echo $partition|cut -d/ -f3)" \
            --inputbox "May reduce disk lifespan!\nWipe times (6GB/min)" 0 30 1) || exit 1
        clear
        wipetime=$(($(fdisk -s $partition) * $times / 8388608))
        yes=$(dialog --stdout --title "Wipe $(echo $partition|cut -d/ -f3)" \
        --yesno "It will take about $wipetime minutes to clean all data!\nConform to wipe $(echo $partition|cut -d/ -f3)!!!" 0 0) || exit 1
        clear
        echo "Fill zero $times time(s). It will take about $wipetime minutes..."
        for ((i=1; i <= $times; i++))
        do
            echo "Fill zero => $i"
            scrub -fp fillzero $partition
        done
        ;;
    F)
        devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | grep sd | tac)
        device=$(dialog --stdout --title "Format disk" --menu "Select HDD device" 7 0 0 $devicelist) || exit 1
        partitionlist=$(lsblk -pln -o name,size $device | sed -e '1d;s/\s\+/ /g')
        partition=$(dialog --stdout --title "Device $device" --menu "Select partition" 7 0 0 $partitionlist) || exit 1
        clear
        yes1=$(dialog --stdout --title "Format" --yesno "Partition $(echo $partition|cut -d/ -f3) to XFS" 0 0) || exit 1
        clear
        yes2=$(dialog --stdout --title "Format XFS" --yesno "   Will clean all data!!\n   Conform to format $(echo $partition|cut -d/ -f3)!!" 0 0) || exit 1
        clear
        [[ $yes1] && [$yes2 ]] && mkfs.xfs $partition
        ;;
esac
