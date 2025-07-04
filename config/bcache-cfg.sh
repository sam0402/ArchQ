#!/bin/bash
c_red_b=$'\e[1;38;5;196m'
c_gray=$'\e[0;37m'
c_write=$'\e[m'
cd ~

WK=$(dialog --stdout --title "ArchQ BCache $1" \
            --menu "!! Caution !! Back up your data before use." 8 0 0 C Create R Remove) || exit 1
clear

if ! pacman -Q bcache-tools >/dev/null 2>&1; then
    echo "Download bcache-tools ..."
    wget -qP /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/bcache-tools-1.1-1-x86_64.pkg.tar.zst
    wget -qP /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/parted-3.5-1-x86_64.pkg.tar.zst
    pacman -U --noconfirm /tmp/bcache-tools-1.1-1-x86_64.pkg.tar.zst /tmp/parted-3.5-1-x86_64.pkg.tar.zst
    echo -e "\nThe system will reboot in 5 seconds.\nAfter that, please go to Config → BCache again."
    for i in {5..1}
    do
        # tput cup 1 25
        echo -n ".$i"
        sleep 1
    done
    reboot
fi

mpc stop >/dev/null 2>&1
case $WK in
    C)
        lsblk -dplnx size -o name | grep -q nvme1 \
            && hddlst=$(lsblk -dplnx size -o name,size | sort -nr | grep -E "sd|nvme") \
            || hddlst=$(lsblk -dplnx size -o name,size | sort -nr | grep "sd")
        [[ -z $hddlst ]] && (echo "No HDD storage device was detected."; exit 1 )
        nvmelst=$(lsblk -dplnx size -o name,size | sort -n | grep "nvme")
        [[ -z $nvmelst ]] && (echo "No SSD or NVMe storage device was detected."; exit 1 )
        # Select HDD partiton
        hdd=$(dialog --stdout --title "Create Bcache" --menu "Select a backing HDD/SSD" 7 0 0 $hddlst) || exit 1
        clear
        hddpartlst=$(lsblk -pln -o name,size,fstype $hdd | sed -e '1d;s/\s\+/ /g;s/\s/,/2')
        hddpart=$(dialog --stdout --title "Backing $hdd" --menu "Select a backing partition" 7 0 0 $hddpartlst) || exit 1
        if lsblk -pln -o fstype $hddpart | grep -q bcache; then
            data=B
        else
            data=$(dialog --stdout --title "Backing $hddpart" --menu "Retain data?" 7 0 0 R Retain C Clean)
            clear
        fi
        # Select SSD/NVME partiton
        nvme=$(dialog --stdout --title "Create Bcache" --menu "Select a cache SSD" 7 0 0 $nvmelst) || exit 1
        clear
        nvmepartlst=$(lsblk -pln -o name,size,fstype $nvme | grep 'p' | sed -e 's/\s\+/ /g;s/\s/,/2')
        nvmepart=$(dialog --stdout --title "Cache $nvme" --menu "Select a cache partition" 7 0 0 $nvmepartlst) || exit 1
        clear
        umount $hddpart
        case $data in
            R)
                # Get sectors range of partition
                start=$(parted $hdd 'unit s' print | grep "^ ${hddpart:0-1}" | awk -F '[[:space:]]*' '{print $3}')
                start_num=${start%s}
                starts=$(( start_num > 16 ? start_num - 16 : 0 ))s
                ends=$(parted $hdd 'unit s' print | grep "^ ${hddpart:0-1}" | awk -F '[[:space:]]*' '{print $4}')
                ends_num=${ends%s}
                if [ "${hddpart:0-1}" -eq 1 ]; then
                    [ "$start_num" -gt 16 ] && work=true
                else
                    prepartnum=$(parted $hdd 'unit s' print | grep -B 1 "^ ${hddpart:0-1}" | grep -v "^ ${hddpart:0-1}" | awk -F '[[:space:]]*' '{ print $2 }')
                    preends=$(parted $hdd 'unit s' print | grep "^ $prepartnum" | awk -F '[[:space:]]*' '{print $4}')
                    [ -n "$starts" ] && [ -n "$preends_num" ] && [ "$start_num" -gt "$preends_num" ] && work=true
                fi
                # Rebuild parititon
                if [ "$work" = "true" ]; then
                    # parted $hdd 'unit s' print
                    newpartnum=$((prepartnum + 1))
                    hddpart=${hddpart::-1}${newpartnum}
                    sfdisk -d $hdd >~/partiton_PreBk_$(date +"%Y%m%d_%H.%M")
                    parted --script $hdd rm ${hddpart:0-1}
                    parted --script $hdd mkpart primary xfs $starts $ends
                    make-bcache -B --force $hddpart
                else
                    echo "Cannot create Bcache without erasing existing data."
                fi
            ;;
            C)
                yes=$(dialog --stdout --title "Create Bcache" --yesno "\n  This action will erase all data.\nDo you want to continue? $hddpart" 0 0) || exit 1
                clear
                $yes && wipefs -a $hddpart || exit 1
                make-bcache -B $hddpart 
            ;;
            B)
                echo "Bcache for $hddpart already exists."
            ;;
        esac
        # Build Bcache
        sleep 5
        bcache=$(lsblk -pln -o name "$hddpart" | grep bcache | cut -d'/' -f3)
        echo -e ${c_gray}"\n--- Create $bcache ---"${c_write}
        lsblk -pln -o fstype $nvmepart | grep -q bcache || (wipefs -af $nvmepart; make-bcache --writeback -C $nvmepart)
        sleep 1
        [ -e /sys/block/$bcache/bcache/attach ] && \
            echo $(bcache-super-show $nvmepart | grep cset | awk '{print $2}') >/sys/block/$bcache/bcache/attach
        # echo writearound >/sys/block/$bcache/bcache/cache_mode
        [ $? -ne 0 ] && echo -e ${c_red_b}"\nYou need to reboot and do it again.\n"${c_write}
        lsblk $hddpart $nvmepart
        ;;
    R)
        # Remove Bcache
        bcache=$(lsblk -pln -o name | grep -m1 bcache | cut -d'/' -f3)
        hddpart=$(lsblk -pn -o size,name | grep -B 1 bcache | grep -E "sd|nvme" | sort -nr | head -n 1 | awk -F '─' '{print $2}')
        hdd=${hddpart%[0-9]}; hdd=${hdd%p}; 
        nvme=$(lsblk -pn -o size,name | grep -B 1 bcache | grep nvme | sort -n | head -n 1 | awk -F '─' '{print $2}')
        if $(dialog --stdout --title "Remove Bcache" --yesno "\n  Remove $bcache ?" 7 0); then   
            umount /dev/$bcache >/dev/null 2>&1
            [ -e /sys/block/$bcache/bcache/attach ] && \
                echo $(bcache-super-show $nvme | grep cset | awk '{print $2}') >/sys/block/$bcache/bcache/detach
            csetfile="/sys/fs/bcache/$(bcache-super-show "$nvme" | awk '/cset\.uuid/ {print $2}')/unregister"
            [ -e "$csetfile" ] && \
                echo 1 > "$csetfile"
            [ -e /sys/block/$bcache/bcache/stop ] && \
                echo 1 >/sys/block/$bcache/bcache/stop
            if lsblk -pln -o fstype $hddpart | grep -q bcache; then
                # Rebuild partition
                start=$(parted $hdd 'unit s' print | grep "^ ${hddpart:0-1}" | awk -F '[[:space:]]*' '{print $3}')
                start_num=${start%s}
                starts=$((start_num + 16))s
                ends=$(parted $hdd 'unit s' print | grep "^ ${hddpart:0-1}" | awk -F '[[:space:]]*' '{print $4}')
                # parted $hdd 'unit s' print
                sfdisk -d $hdd >~/partiton_CachBk_$(date +"%Y%m%d_%H.%M")
                parted --script $hdd rm ${hddpart:0-1} >/dev/null 2>&1
                parted --script $hdd mkpart primary xfs $starts $ends
            fi
        fi
        echo -e ${c_red_b}"\nReboot now [Y/n]? "${c_write}
        input=''; read input
        [[ -z $input || $input = y ]] && reboot
        ;;
esac
