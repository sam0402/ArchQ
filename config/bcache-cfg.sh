#!/bin/bash
RED=$'\e[1;38;5;196m'
GRAY=$'\e[0;37m'
RESET=$'\e[m'
cd ~

ACTION=$(dialog --stdout --title "ArchQ BCache $1" \
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
case $ACTION in
    C)
        # Detect Storage Devices
        lsblk -dplnx size -o name | grep -q nvme1 && \
            DISK_LIST=$(lsblk -dplnx size -o name,size | sort -n | grep -E "sd|nvme") || \
            DISK_LIST=$(lsblk -dplnx size -o name,size | sort -n | grep "sd")
        
        [[ -z $DISK_LIST ]] && { echo "No HDD storage device was detected."; exit 1; }
        SSD_LIST=$(lsblk -dplnx size -o name,size | sort -nr | grep "nvme")
        [[ -z $SSD_LIST ]] && { echo "No SSD or NVMe storage device was detected."; exit 1; }

        # Select HDD partiton
        BACKING_DISK=$(dialog --stdout --title "Create Bcache" --menu "Select a backing HDD/SSD" 7 0 0 $DISK_LIST) || exit 1
        clear
        BACKING_PART_LIST=$(lsblk -pln -o name,size,fstype $BACKING_DISK | sed -e '1d;s/\s\+/ /g;s/\s/,/2')
        if [ -z "$BACKING_PART_LIST" ]; then
            if dialog --stdout --title "No Partition" --yesno "\nNo partitions found on $BACKING_DISK.\nCreate a partition using the whole disk?" 0 0; then
                clear
                parted --script $BACKING_DISK -- mklabel gpt \
                    mkpart BCache xfs 1MiB 100%
                echo "Partition created on $BACKING_DISK."
                # Refresh partition list
                BACKING_PART_LIST=$(lsblk -pln -o name,size,fstype $BACKING_DISK | sed -e '1d;s/\s\+/ /g;s/\s/,/2')
            else
                echo "No partition created. Exiting."
                exit 1
            fi
        fi
        BACKING_PART=$(dialog --stdout --title "Backing $BACKING_DISK" --menu "Select a backing partition" 7 0 0 $BACKING_PART_LIST) || exit 1
        if lsblk -pln -o fstype $BACKING_PART | grep -q bcache; then
            # data=$(dialog --stdout --title "Backing $BACKING_PART" --menu "Bcache detected" 7 0 0 B "Use existing" C "Clean & Create")
            data=B
            clear
        else
            data=$(dialog --stdout --title "Backing $BACKING_PART" --menu "Retain data?" 7 0 0 R Retain C Clean)
            clear
        fi
        # Select SSD/NVME partiton
        CACHE_DISK=$(dialog --stdout --title "Create Bcache" --menu "Select a cache SSD" 7 0 0 $SSD_LIST) || exit 1
        clear
        CACHE_PART_LIST=$(lsblk -pln -o name,size,fstype $CACHE_DISK | grep 'p' | sed -e 's/\s\+/ /g;s/\s/,/2')
        CACHE_PART=$(dialog --stdout --title "Cache $CACHE_DISK" --menu "Select a cache partition" 7 0 0 $CACHE_PART_LIST) || exit 1
        clear
        umount $BACKING_PART
        case $data in
            R)
                # Get sectors range of partition
                part_num=$(cat /sys/class/block/${BACKING_PART##*/}/partition 2>/dev/null)
                [ -z "$part_num" ] && { echo "Could not determine partition number for $BACKING_PART."; exit 1; }
                p_info=$(parted -m "$BACKING_DISK" unit s print | grep "^${part_num}:")
                start_s=$(echo "$p_info" | cut -d: -f2 | tr -d 's')
                end_s=$(echo "$p_info" | cut -d: -f3 | tr -d 's')
                
                work=false
                if [ "$part_num" -eq 1 ]; then
                    [ "$start_s" -ge 16 ] && work=true
                else
                    # Check gap with previous partition
                    # Find the highest end sector less than current start
                    prev_end_s=$(parted -m "$BACKING_DISK" unit s print | grep -v "^${part_num}:" | awk -F: -v s="$start_s" '{gsub("s","",$3); if ($3 < s) print $3}' | sort -nr | head -n1)
                    if [ -z "$prev_end_s" ]; then
                         [ "$start_s" -ge 16 ] && work=true
                    else
                         gap=$((start_s - prev_end_s))
                         [ "$gap" -ge 16 ] && work=true
                    fi
                fi
                # Rebuild parititon
                if [ "$work" = "true" ]; then
                    sfdisk -d $BACKING_DISK >~/partiton_PreBk_$(date +"%Y%m%d_%H.%M")
                    new_start_s=$((start_s - 16))
                    parted --script $BACKING_DISK rm $part_num
                    parted --script $BACKING_DISK mkpart BCache xfs ${new_start_s}s ${end_s}s
                    sleep 1
                    make-bcache -B --force $BACKING_PART
                else
                    echo "Cannot create Bcache without erasing existing data (insufficient space)."
                    exit 1
                fi
            ;;
            C)
                dialog --stdout --title "Create Bcache" --yesno "\n  This action will erase all data.\nDo you want to continue? $BACKING_PART" 0 0 && wipefs -a $BACKING_PART || exit 1
                clear
                make-bcache -B $BACKING_PART 
            ;;
            B)
                echo "Bcache for $BACKING_PART already exists."
                modprobe bcache >/dev/null 2>&1
                [ -f /sys/fs/bcache/register ] && echo "$BACKING_PART" > /sys/fs/bcache/register 2>/dev/null
                BP_EXIST=true
            ;;
        esac
        # Build Bcache
        for i in {1..5}; do
            bcache=$(lsblk -pln -o name "$BACKING_PART" | grep bcache | cut -d'/' -f3)
            [ -n "$bcache" ] && break
            sleep 1
        done
        [ -z "$bcache" ] && { echo "Error: Bcache device not found on $BACKING_PART"; exit 1; }
        echo -e ${GRAY}"\n--- Create $bcache ---"${RESET}
        lsblk -pln -o fstype $CACHE_PART | grep -q bcache || (wipefs -af $CACHE_PART; make-bcache --writeback -C $CACHE_PART)
        sleep 1
        [ -e /sys/block/$bcache/bcache/attach ] && \
            echo $(bcache-super-show $CACHE_PART | grep cset | awk '{print $2}') >/sys/block/$bcache/bcache/attach
        # echo writearound >/sys/block/$bcache/bcache/cache_mode
        if [ $? -ne 0 ] && [ "$BP_EXIST" = true ]; then
            if dialog --stdout --title "Failed to create Bcache." --yesno "\n Need to remove $BACKING_PART and create again. This may delete all data." 7 0; then
                [ -e "/sys/block/$bcache/bcache/stop" ] && echo 1 > "/sys/block/$bcache/bcache/stop"
                sleep 1
                BACKING_DISK="/dev/$(basename $(readlink -f /sys/class/block/${BACKING_PART##*/}/..))"
                part_num=$(cat /sys/class/block/${BACKING_PART##*/}/partition)
                parted -s "$BACKING_DISK" rm "$part_num"
            fi
            echo -e ${RED}"\nYou need to reboot and create Bcache again.\n"${RESET}
        fi
        lsblk $BACKING_PART $CACHE_PART
        ;;
    R)
        # Remove Bcache
        bcache_path=$(lsblk -pln -o name | grep -m1 "/bcache[0-9]")
        [ -z "$bcache_path" ] && { echo "No bcache device found."; exit 1; }
        bcache=${bcache_path##*/}

        # Identify Backing Partition via sysfs slaves (No PKNAME)
        if [ -d "/sys/block/$bcache/slaves" ]; then
            slave=$(ls /sys/block/$bcache/slaves | head -n1)
            BACKING_PART="/dev/$slave"
        else
            echo "Error: Could not identify backing device for $bcache"
            exit 1
        fi

        # Identify Cache Partition (Device with bcache fstype that is not the backing part)
        CACHE_PART=$(lsblk -pln -o name,fstype | awk -v b="$BACKING_PART" '$2 == "bcache" && $1 != b && $1 !~ /bcache/ {print $1; exit}')

        # Identify Backing Disk
        BACKING_DISK="/dev/$(basename $(readlink -f /sys/class/block/${BACKING_PART##*/}/..))"

        if dialog --stdout --title "Remove Bcache" --yesno "\n  Remove $bcache ?" 7 0; then
            umount "$bcache_path" >/dev/null 2>&1
            
            # Stop Bcache & Unregister
            if [ -n "$CACHE_PART" ]; then
                cset_uuid=$(bcache-super-show "$CACHE_PART" | awk '/cset.uuid/ {print $2}')
                [ -n "$cset_uuid" ] && [ -f "/sys/fs/bcache/$cset_uuid/unregister" ] && echo 1 > "/sys/fs/bcache/$cset_uuid/unregister"
                # wipefs -a "$CACHE_PART"
            fi
            [ -e "/sys/block/$bcache/bcache/stop" ] && echo 1 > "/sys/block/$bcache/bcache/stop"

            if lsblk -pln -o fstype $BACKING_PART | grep -q bcache; then
                # Rebuild partition
                part_num=$(cat /sys/class/block/${BACKING_PART##*/}/partition)
                p_info=$(parted -m "$BACKING_DISK" unit s print | grep "^${part_num}:")
                start_s=$(echo "$p_info" | cut -d: -f2 | tr -d 's')
                end_s=$(echo "$p_info" | cut -d: -f3 | tr -d 's')
                
                new_start_s=$((start_s + 16))
                
                sfdisk -d $BACKING_DISK >~/partiton_CachBk_$(date +"%Y%m%d_%H.%M")
                parted --script $BACKING_DISK rm $part_num >/dev/null 2>&1
                parted --script $BACKING_DISK mkpart Linux xfs ${new_start_s}s ${end_s}s >/dev/null 2>&1
                echo -e ${GRAY}"\n--- $bcache Removed ---"${RESET}
                lsblk -pln -o name,size,fstype $BACKING_PART
            fi
        fi
        echo -e ${RED}"\nReboot now [Y/n]? "${RESET}
        read -r input
        [[ -z $input || $input = y ]] && reboot
        ;;
esac