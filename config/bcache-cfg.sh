#!/bin/bash
WK=$(dialog --stdout --title "ArchQ Bcache $1" \
            --menu "!! Caution !! Backup your data befort use." 8 0 0 C Create R Remove) || exit 1
clear

if ! pacman -Q bcache-tools >/dev/null 2>&1; then
    pacman -Sy --noconfirm archlinux-keyring
    pacman -S --noconfirm parted
    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/bcache-tools-1.1-1-x86_64.pkg.tar.zst
    pacman -U --noconfirm /root/bcache-tools-1.1-1-x86_64.pkg.tar.zst
    echo -e "\nSystem will reboot after 5 seconds."
    for i in {5..1}
    do
        tput cup 1 25
        echo -n "$i"
        sleep 1
    done
    reboot
fi

case $WK in
    C)
        hddlst=$(lsblk -dplnx size -o name,size | grep "sd" | tac)
        nvmelst=$(lsblk -dplnx size -o name,size | grep "nvme" | tac)
        [[ -z $nvmelst ]] && (echo "No SSD/NVME device." ; exit 1 )
        # Select HDD partiton
        hdd=$(dialog --stdout --title "Bache create" --menu "Select HDD" 7 0 0 $hddlst) || exit 1
        clear
        hddpartlst=$(lsblk -pln -o name,size,fstype $hdd | sed -e '1d;s/\s\+/ /g;s/\s/,/2')
        hddpart=$(dialog --stdout --title "Device $hdd" --menu "Select partition" 7 0 0 $hddpartlst) || exit 1
        if lsblk -pln -o fstype $hddpart | grep -q bcache; then
            data=B
        else
            data=$(dialog --stdout --title "Device $hddpart" --menu "Retain data?" 7 0 0 R Retain C Clean)
            clear
        fi
        # Select SSD/NVME partiton
        nvme=$(dialog --stdout --title "Bache create" --menu "Select cache SSD" 7 0 0 $nvmelst) || exit 1
        clear
        nvmepartlst=$(lsblk -pln -o name,size,fstype $nvme | sed -e '1d;s/\s\+/ /g;s/\s/,/2')
        nvmepart=$(dialog --stdout --title "Cache $nvme" --menu "Select partition" 7 0 0 $nvmepartlst) || exit 1
        clear
        case $data in
            R)
                # Get sectors range of partition
                start=$(parted $hdd 'unit s' print | grep "^ ${hddpart:0-1}" | awk -F '[[:space:]]*' '{ print $3 }')
                starts=$(expr ${start::-1} - 16)s
                ends=$(parted $hdd 'unit s' print | grep "^ ${hddpart:0-1}" | awk -F '[[:space:]]*' '{ print $4 }')
                if [ ${hddpart:0-1} -eq 1 ]; then
                    [ $(expr ${start::-1} - 16) -gt 0 ] && work=true
                else
                    prepartnum=$(expr ${hddpart:0-1} - 1)
                    preends=$(parted $hdd 'unit s' print | grep "^ $prepartnum" | awk -F '[[:space:]]*' '{ print $4 }')
                    [ ${starts::-1} -gt ${preends::-1} ] && work=true
                fi
                # Rebuild parititon
                if "$work"; then
                    # parted $hdd 'unit s' print
                    sfdisk -d $hdd >./partiton_backup_$(date +"%Y%m%d_%H.%M")
                    parted --script $hdd rm ${hddpart:0-1}
                    parted --script $hdd mkpart primary xfs $starts $ends
                    make-bcache -B $hddpart
                else
                    echo "Can not create Bcache with retaining data."
                fi
            ;;
            C)
                yes=$(dialog --stdout --title "Bache create" --yesno "\n  It will clean all data.\nConform to clean $hddpart" 0 0) || exit 1
                clear
                $yes && wipefs -a $hddpart || exit 1
                make-bcache -B $hddpart
            ;;
            B)
                echo "Bcache of $hddpart is exist."
            ;;
        esac
        # Build Bcache
        sleep 5
        bcache=$(lsblk -pln -o name "$hddpart" | grep bcache | cut -d'/' -f3)
        echo --- $bcache ---
        lsblk -pln -o fstype $nvmepart | grep -q bcache || (wipefs -af $nvmepart; make-bcache -C $nvmepart)
        sleep 1
        echo $(bcache-super-show $nvmepart | grep cset | awk '{print $2}') >/sys/block/$bcache/bcache/attach
        [ $? -ne 0 ] && echo -e "\nNeet to do it again or reboot.\n"
        lsblk $hddpart $nvmepart
        ;;
    R)
        # Remove Bcache
        bcache=$(lsblk -pln -o name | grep -m1 bcache | cut -d'/' -f3)
        hddpart=$(lsblk -pn -o name | grep -B 1 bcache | grep sd | awk -F '─' '{ print $2}')
        hdd=${hddpart::-1}
        nvme=$(lsblk -pn -o name | grep -B 1 bcache | grep nvme | awk -F '─' '{ print $2}')
        if $(dialog --stdout --title "Bache remove" --yesno "\n  Remove $bcache ?" 7 0); then   
            umount /dev/$bcache
            echo $(bcache-super-show $nvme | grep cset | awk '{print $2}') >/sys/block/$bcache/bcache/detach
            echo 1 >/sys/fs/bcache/`bcache-super-show $nvme | grep cset | awk '{print $2}'`/unregister
            echo 1 >/sys/block/$bcache/bcache/stop
            if lsblk -pln -o fstype $hddpart | grep -q bcache; then
                # Rebuild partition
                start=$(parted $hdd 'unit s' print | grep "^ ${hddpart:0-1}" | awk -F '[[:space:]]*' '{ print $3 }')
                starts=$(expr ${start::-1} + 16)s
                ends=$(parted $hdd 'unit s' print | grep "^ ${hddpart:0-1}" | awk -F '[[:space:]]*' '{ print $4 }')
                # parted $hdd 'unit s' print
                sfdisk -d $hdd >./partiton_backup_$(date +"%Y%m%d_%H.%M")
                parted --script $hdd rm ${hddpart:0-1}
                parted --script $hdd mkpart primary xfs $starts $ends
            fi
        fi
        echo -e "\nReboot now [Y/n]? "
        input=''; read input
        [[ -z $input || $input = y ]] && reboot
        ;;
esac
