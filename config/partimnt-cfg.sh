#!/bin/bash
config='/etc/fstab'
WK=$(dialog --stdout --title "ArchQ $1" \
            --menu "Partition mount point" 7 0 0 M Mount E Eject)
clear
case $WK in
    M)
        devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
        device=$(dialog --stdout --title "Mount partition" --menu "Select device" 7 0 0 ${devicelist}) || exit 1
        clear
        partitionlist=$(lsblk -pln -o name,size,fstype ${device} | sed -e '1d;s/\s\+/ /g;s/\s/,/2')
        partition=$(dialog --stdout --title "Device ${device}" --menu "Select partition" 7 0 0 ${partitionlist}) || exit 1
        clear
        partdata=$(lsblk -pln -o name,fstype,uuid ${partition})
        PT=$(echo $partdata | cut -d ' ' -f 1)
        FS=$(echo $partdata | cut -d ' ' -f 2)
        ID=$(echo $partdata | cut -d ' ' -f 3)

        OP='rw'
        [ $FS = ext4 ] && OP='defaults'
        [ $FS = hfsplus ] && OP='rw,force,uid=1000,gid=1000'
        [ $FS = apfs ] && OP='readwrite'
        [ $FS = f2fs ] && OP='noatime'
        if [ $FS = ntfs ]; then
            FS=ntfs3; OP='iocharset=utf8'
        fi

        options=$(dialog --stdout \
            --title "Partition ${partition} ($FS)" \
            --ok-label "Ok" \
            --form "Mount setting" 0 40 0 \
            "Mount Point /mnt/" 1 1   ""  1 18 40 0 \
            "Options"           2 1   "$OP"  2 18 40 0) || exit 1
        clear
        MP=$(echo $options |  awk '//{print $1 }')
        OP=$(echo $options |  awk '//{print $2 }')
        [ -z $OP ] && echo "Fail! Mount point is null." && exit 1

        echo "UUID=${ID} /mnt/${MP} $FS ${OP} 0 0" >>$config
        echo "Add $partition ($FS) to /mnt/$MP mount point."
        [ -d "/mnt/${MP}" ] && mount /mnt/${MP} && echo and mounting.
        systemctl daemon-reload
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
        umount /mnt/${MP}
        sed -i '/\/mnt\/'"$MP"'/d' $config
        echo Eject /mnt/$MP and delete mount point.
        ;;
esac
