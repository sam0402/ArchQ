#!/bin/bash
config='/etc/fstab'
user=$(grep '1000' /etc/passwd | awk -F: '{print $1}')

WK=$(dialog --stdout --title "ArchQ $1" \
            --menu "Partition mount point" 7 0 0 M Mount E Eject)
clear
case $WK in
    M)
        devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
        device=$(dialog --stdout --title "Mount partition" --menu "Select device" 7 0 0 $devicelist) || exit 1
        clear
        partitionlist=$(lsblk -pln -o name,size,fstype $device | sed -e '1d;s/\s\+/ /g;s/\s/,/2')
        partition=$(dialog --stdout --title "Device $device" --menu "Select partition" 7 0 0 $partitionlist) || exit 1
        clear
        partdata=$(lsblk -pln -o name,fstype,uuid $partition)
        PT=$(echo $partdata | cut -d ' ' -f 1)
        FS=$(echo $partdata | cut -d ' ' -f 2)
        ID=$(echo $partdata | cut -d ' ' -f 3)

        OP='rw' 
        [ $FS = ext4 ] && OP='defaults'
        [ $FS = hfsplus ] && OP='rw,force,noatime'
        [ $FS = apfs ] && OP='readwrite'
        [ $FS = f2fs ] && OP='rw'
        if [ $FS = ntfs ]; then
            FS=ntfs3; OP='iocharset=utf8'
        fi

        options=$(dialog --stdout \
            --title "Partition $partition ($FS)" \
            --ok-label "Ok" \
            --form "Mount setting" 0 40 0 \
            "Mount Point /mnt/" 1 1   ""  1 18 40 0 \
            "Options"           2 1   "$OP"  2 18 40 0) || exit 1
        clear
        MP=$(echo $options |  awk '//{print $1 }')
        OP=$(echo $options |  awk '//{print $2 }')
        [ $FS = f2fs ] && OP+= \
        ',relatime,lazytime,background_gc=on,nodiscard,no_heap,inline_xattr,inline_data,inline_dentry,flush_merge,extent_cache,mode=adaptive,active_logs=6,alloc_mode=default,checkpoint_merge,fsync_mode=posix,discard_unit=block,memory=normal'
        [ -z $OP ] && echo "Fail! Mount point is null." && exit 1

        mntuser=$(dialog --stdout --title "Mount point /mnt/$MP" \
            --radiolist "Set permission to" 7 0 0 \
             root '　' on \
            $user '　' off) || exit 1
        clear

        [[ $mntuser != root && $FS =~ fat ]] && OP='rw,uid=1000,gid=1000'
        [[ $mntuser != root && $FS =~ ntfs ]] && OP='iocharset=utf8,uid=1000,gid=1000'

        echo "UUID=$ID /mnt/$MP $FS $OP 0 0" >>$config
        systemctl daemon-reload

        echo "Add $partition ($FS) to /mnt/$MP mount point."
        
        if [ $mntuser != root ]; then
            mkdir /mnt/$MP
            mount /mnt/$MP
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
                --menu "Select to delete" 7 0 0 $MENU) || exit 1
                clear
        MP=$(echo $options | cut -d '/' -f 3)
        umount /mnt/$MP
        sed -i '/\/mnt\/'"$MP"'/d' $config
        systemctl daemon-reload
        echo Eject /mnt/$MP and delete mount point.
        ;;
esac
