#!/bin/bash
set -e
WK=$(dialog --stdout --title "ArchQ $1" \
            --menu "Bcache" 7 0 0 C Creat R Remove) || exit 1
clear

if ! pacman -Q bcache-tools >/dev/null 2>&1; then
    pacman -Sy --noconfirm archlinux-keyring
    pacman -S --noconfirm parted
    wget -qP /root https://raw.githubusercontent.com/sam0322/ArchQ/main/pkg/bcache-tools-1.1-1-x86_64.pkg.tar.zst
    pacman -U --noconfirm /root/bcache-tools-1.1-1-x86_64.pkg.tar.zst
fi

case $WK in
    C)
        hddlst=$(lsblk -dplnx size -o name,size | grep "sd" | tac)
        nvmelst=$(lsblk -dplnx size -o name,size | grep "nvme" | tac)
        # Select HDD partiton
        hdd=$(dialog --stdout --title "Bache creat" --menu "Select HDD" 7 0 0 $hddlst) || exit 1
        clear
        hddpartlst=$(lsblk -pln -o name,size,fstype $hdd | sed -e '1d;s/\s\+/ /g;s/\s/,/2')
        hddpart=$(dialog --stdout --title "Device $hdd" --menu "Select partition" 7 0 0 $hddpartlst) || exit 1
        data=$(dialog --stdout --title "Device $hddpart" --menu "Retain data?" 7 0 0 R Retain C Clean)
        clear
        # Select SSD/NVME partiton
        nvme=$(dialog --stdout --title "Bache creat" --menu "Select cache SSD" 7 0 0 $nvmelst) || exit 1
        clear
        nvmepartlst=$(lsblk -pln -o name,size,fstype $nvme | sed -e '1d;s/\s\+/ /g;s/\s/,/2')
        nvmepart=$(dialog --stdout --title "Cache $nvme" --menu "Select partition" 7 0 0 $nvmepartlst) || exit 1
        clear
        if [ $data = R ]; then
            # Get sectors range of partition
            start=$(parted $hdd 'unit s' print | grep "^ ${hddpart:0-1}" | awk -F '[[:space:]]*' '{ print $3 }')
            starts=$(expr ${start::-1} - 16)s
            ends=$(parted $hdd 'unit s' print | grep "^ ${hddpart:0-1}" | awk -F '[[:space:]]*' '{ print $4 }')
            if [ ${hddpart:0-1} -ge 2 ]; then
                prepartnum=$(expr ${hddpart:0-1} - 1)
                preends=$(parted $hdd 'unit s' print | grep "^ $prepartnum" | awk -F '[[:space:]]*' '{ print $4 }')
                [ ${preends::-1} -ge ${starts::-1} ] && ( echo "The partition can not retain data for adding cache!" ; exit 1 )
            fi
            # Rebuild parititon
            # parted $hdd 'unit s' print
            parted --script $hdd rm ${hddpart:0-1}
            parted --script $hdd mkpart primary xfs $starts $ends
        else
            wipefs -a $hddpart
        fi
        # Build Bcache
        wipefs -a $nvmepart
        make-bcache -C $nvmepart
        make-bcache -B $hddpart
        echo $(bcache-super-show $nvmepart | grep cset | awk '{print $2}') >/sys/block/bcache0/bcache/attach
        lsblk
        ;;
    R)
        # Remove Bcache
        bcache=$(lsblk -pln -o name | grep -m1 bcache)
        hddpart=$(lsblk -pn -o name | grep -B 1 bcache | grep sd | awk -F '─' '{ print $2}')
        hdd=${hddpart::-1}
        nvme=$(lsblk -pn -o name | grep -B 1 bcache | grep nvme | awk -F '─' '{ print $2}')
        if $(dialog --stdout --title "Bache remove" --yesno "\n  Remove $bcache ?" 7 0); then   
            umount $bcache
            echo $(bcache-super-show $nvme | grep cset | awk '{print $2}') >/sys/block/$bcache/bcache/detach
            echo 1 >/sys/fs/bcache/`bcache-super-show $nvme | grep cset | awk '{print $2}'`/unregister
            echo 1 >/sys/block/$bcache/bcache/stop
            # Rebuild partition
            start=$(parted $hdd 'unit s' print | grep "^ ${hddpart:0-1}" | awk -F '[[:space:]]*' '{ print $3 }')
            starts=$(expr ${start::-1} + 16)s
            ends=$(parted $hdd 'unit s' print | grep "^ ${hddpart:0-1}" | awk -F '[[:space:]]*' '{ print $4 }')
            # parted $hdd 'unit s' print
            parted --script $hdd rm ${hddpart:0-1}
            parted --script $hdd mkpart primary xfs $starts $ends
        fi
        ;;
esac