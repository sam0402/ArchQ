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
            && hddlst=$(lsblk -dplnx size -o name,size | sort -n | grep -E "sd|nvme") \
            || hddlst=$(lsblk -dplnx size -o name,size | sort -n | grep "sd")
        [[ -z $hddlst ]] && (echo "No HDD storage device was detected."; exit 1 )
        nvmelst=$(lsblk -dplnx size -o name,size | sort -nr | grep "nvme")
        [[ -z $nvmelst ]] && (echo "No SSD or NVMe storage device was detected."; exit 1 )
        # Select HDD partiton
        hdd=$(dialog --stdout --title "Create Bcache" --menu "Select a backing HDD/SSD" 7 0 0 $hddlst) || exit 1
        clear
        hddpartlst=$(lsblk -pln -o name,size,fstype $hdd | sed -e '1d;s/\s\+/ /g;s/\s/,/2')
        if [ -z "$hddpartlst" ]; then
            if dialog --stdout --title "No Partition" --yesno "\nNo partitions found on $hdd.\nCreate a partition using the whole disk?" 0 0; then
                clear
                parted --script $hdd -- mklabel gpt \
                    mkpart BCache xfs 1MiB 100%
                echo "Partition created on $hdd."
                # Refresh partition list
                hddpartlst=$(lsblk -pln -o name,size,fstype $hdd | sed -e '1d;s/\s\+/ /g;s/\s/,/2')
            else
                echo "No partition created. Exiting."
                exit 1
            fi
        fi
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
                # FIX: Use lsblk and parted -m for robust parsing
                part_num=$(lsblk -no PARTN "$hddpart")
                p_info=$(parted -m "$hdd" unit s print | grep "^${part_num}:")
                start_s=$(echo "$p_info" | cut -d: -f2 | tr -d 's')
                end_s=$(echo "$p_info" | cut -d: -f3 | tr -d 's')
                
                work=false
                if [ "$part_num" -eq 1 ]; then
                    [ "$start_s" -ge 16 ] && work=true
                else
                    # Check gap with previous partition
                    # Find the highest end sector less than current start
                    prev_end_s=$(parted -m "$hdd" unit s print | grep -v "^${part_num}:" | awk -F: -v s="$start_s" '{gsub("s","",$3); if ($3 < s) print $3}' | sort -nr | head -n1)
                    if [ -z "$prev_end_s" ]; then
                         [ "$start_s" -ge 16 ] && work=true
                    else
                         gap=$((start_s - prev_end_s))
                         [ "$gap" -ge 16 ] && work=true
                    fi
                fi
                # Rebuild parititon
                if [ "$work" = "true" ]; then
                    sfdisk -d $hdd >~/partiton_PreBk_$(date +"%Y%m%d_%H.%M")
                    new_start_s=$((start_s - 16))
                    parted --script $hdd rm $part_num
                    parted --script $hdd mkpart BCache xfs ${new_start_s}s ${end_s}s
                    sleep 1
                    make-bcache -B --force $hddpart
                else
                    echo "Cannot create Bcache without erasing existing data (insufficient space)."
                    exit 1
                fi
            ;;
            C)
                dialog --stdout --title "Create Bcache" --yesno "\n  This action will erase all data.\nDo you want to continue? $hddpart" 0 0 && wipefs -a $hddpart || exit 1
                clear
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
        bcache_path=$(lsblk -pln -o name | grep -m1 bcache)
        [ -z "$bcache_path" ] && { echo "No bcache device found."; exit 1; }
        bcache=${bcache_path##*/}
        
        hddpart=$(lsblk -no PKNAME "$bcache_path")
        hddpart="/dev/$hddpart"
        hdd_dev=$(lsblk -no PKNAME "$hddpart")
        hdd="/dev/$hdd_dev"
        
        # Try to find cache set uuid (SSD) if possible, keeping original heuristic logic for nvme var
        nvme=$(lsblk -pn -o size,name | grep -B 1 bcache | grep nvme | sort -n | head -n 1 | awk -F '─' '{print $2}')
        
        if $(dialog --stdout --title "Remove Bcache" --yesno "\n  Remove $bcache ?" 7 0); then   
            umount "$bcache_path" >/dev/null 2>&1
            if [ -e /sys/block/$bcache/bcache/attach ]; then
                [ -n "$nvme" ] && echo $(bcache-super-show $nvme | grep cset | awk '{print $2}') >/sys/block/$bcache/bcache/detach
                [ -n "$nvme" ] && csetfile="/sys/fs/bcache/$(bcache-super-show "$nvme" | awk '/cset\.uuid/ {print $2}')/unregister"
                [ -n "$csetfile" ] && echo 1 > "$csetfile"
                echo 1 >/sys/block/$bcache/bcache/stop
            fi
            if lsblk -pln -o fstype $hddpart | grep -q bcache; then
                # Rebuild partition
                part_num=$(lsblk -no PARTN "$hddpart")
                p_info=$(parted -m "$hdd" unit s print | grep "^${part_num}:")
                start_s=$(echo "$p_info" | cut -d: -f2 | tr -d 's')
                end_s=$(echo "$p_info" | cut -d: -f3 | tr -d 's')
                
                new_start_s=$((start_s + 16))
                
                sfdisk -d $hdd >~/partiton_CachBk_$(date +"%Y%m%d_%H.%M")
                parted --script $hdd rm $part_num >/dev/null 2>&1
                parted --script $hdd mkpart Linux xfs ${new_start_s}s ${end_s}s >/dev/null 2>&1
            fi
        fi
        echo -e ${c_red_b}"\nReboot now [Y/n]? "${c_write}
        input=''; read input
        [[ -z $input || $input = y ]] && reboot
        ;;
esac
