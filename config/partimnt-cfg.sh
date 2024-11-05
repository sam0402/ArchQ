#!/bin/bash
config='/etc/fstab'
user=$(grep '1000' /etc/passwd | awk -F: '{print $1}')

WK=$(dialog --stdout --title "ArchQ $1" \
            --menu "Partition mount point" 7 0 0 M Mount E Eject) || exit 1; clear
case $WK in
    M)
        devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
        device=$(dialog --stdout --title "Mount partition" --menu "Select device" 7 0 0 $devicelist) || exit 1; clear
        partitionlist=$(lsblk -pln -o name,size,fstype $device | sed -e '1d;s/\s\+/ /g;s/\s/,/2')
        partition=$(dialog --stdout --title "Device $device" --menu "Select partition" 7 0 0 $partitionlist) || exit 1; clear
        partdata=$(lsblk -pln -o name,fstype,uuid $partition)
        PT=$(echo $partdata | cut -d ' ' -f 1)
        FS=$(echo $partdata | cut -d ' ' -f 2)
        ID=$(echo $partdata | cut -d ' ' -f 3)

        OP='rw,noatime' 
        [ $FS = ext4 ] && OP+=',defaults'
        [ $FS = hfsplus ] && OP+=',force'
        if [ $FS = ntfs ]; then
            FS=ntfs3; OP+=',iocharset=utf8'
        fi
        [ $FS = exfat ] && OP+=',iocharset=utf8'
        [ $FS = apfs ] && OP='readwrite,noatime'

        options=$(dialog --stdout \
            --title "Partition $partition ($FS)" \
            --ok-label "Ok" \
            --form "Mount setting" 0 40 0 \
            "Mount Point /mnt/" 1 1   ""  1 18 40 0 \
            "Options"           2 1   "$OP"  2 18 40 0) || exit 1
        clear
        MP=$(echo $options |  awk '//{print $1 }')
        OP=$(echo $options |  awk '//{print $2 }')
        [ $FS = xfs ] && OP+=',attr2,inode64,logbufs=8,logbsize=32k,noquota'
        [ $FS = f2fs ] && OP+=',background_gc=on,no_heap,inline_xattr,inline_data,inline_dentry,flush_merge,extent_cache,mode=adaptive,active_logs=6,alloc_mode=reuse,checkpoint_merge,fsync_mode=posix,discard_unit=block,memory=normal'
        [ -z $OP ] && echo "Fail! Mount point is null." && exit 1

    # mount for root || user
        mntuser=$(dialog --stdout --title "Mount point /mnt/$MP" \
            --radiolist "Set permission to" 7 0 0 \
            $user '　' on \
             root '　' off ) || exit 1; clear

        [[ $mntuser != root && $FS =~ fat ]] && OP+=',uid=1000,gid=1000'
        [[ $mntuser != root && $FS =~ ntfs ]] && OP+=',uid=1000,gid=1000'

    # for USB storage
        usb=$(dialog --stdout --title "Mount point /mnt/$MP" \
            --radiolist "USB storage auto mount" 7 0 0 \
            Yes '　' on \
            No '　' off ) || exit 1; clear

        [ $usb = Yes ] && tag='#' || tag=''
        [ $usb = Yes ] && OP="noauto,$OP"

        echo "${tag}UUID=$ID /mnt/$MP $FS $OP 0 0" >>$config
        systemctl daemon-reload

        echo "Add $partition ($FS) to /mnt/$MP mount point."
        
        if [ $mntuser != root ] && [ $usb == No ]; then
            mount -m /mnt/$MP
            [[ $FS =~ fat ]] || chown $user: /mnt/$MP && echo "Set /mnt/$MP permission to $user."
        fi

        [ -d "/mnt/$MP" ] && mount -o remount /mnt/$MP && echo "and mounting."
        ;;
    E)
        MENU=''
        while read line; do
                MPs=$(echo $line | cut -d ' ' -f 2 | cut -d '/' -f 3)
                MENU=${MENU}' /mnt/'$MPs' 　'
        done <<< $(cat $config | grep mnt | grep -v nfs)

        options=$(dialog --stdout \
                --title "Eject partition" \
                --menu "Select to delete" 7 0 0 $MENU) || exit 1; clear
        MP=$(echo $options | cut -d '/' -f 3)
        umount /mnt/$MP
        sed -i '/\/mnt\/'"$MP"'/d' $config
        systemctl daemon-reload
        echo Eject /mnt/$MP and delete mount point.
        ;;
esac
