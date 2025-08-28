#!/bin/bash
while read line; do
    list+=${line}' 　 '
done <<< $(ls /mnt)

SOURCE=$(dialog --stdout \
        --title "Synchronization Backup $1" \
        --menu "Source (/mnt)" 7 0 0 ${list}) || exit 1; clear

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --title "Synchronization Backup $1" --menu "Select target disk" 7 0 0 $devicelist) || exit 1; clear
partitionlist=$(lsblk -pln -o name,size,fstype $device | sed -e '1d;s/\s\+/ /g;s/\s/,/2')
partition=$(dialog --stdout --title "Synchronization Backup $device" --menu "Select partition" 7 0 0 $partitionlist) || exit 1; clear
partdata=$(lsblk -pln -o name,fstype $partition)

options=$(dialog --stdout --title "Synchronization Backup $1" --checklist "" 7 0 0 \
        D "Delete files don't exist in the source" on \
        U "Umount partition after finished" on) || exit 1; clear
[[ $options =~ D ]] && DEL="--delete"
[[ $options =~ D ]] && delmsg=",\nand deletes files in the destination if they don't exist in the source"

PT=$(echo $partdata | cut -d ' ' -f 1)
FS=$(echo $partdata | cut -d ' ' -f 2)
OP='rw' 
[ $FS = ext4 ] && OP='defaults,noatime'
[ $FS = hfsplus ] && OP='rw,force,noatime,nls=utf8'
[ $FS = apfs ] && OP='readwrite'
[ $FS = f2fs ] && OP='rw,noatime'
[ $FS = exfat ] && OP='rw,noatime,iocharset=utf8'

if [ $FS = ntfs ]; then
    FS=ntfs3; OP='iocharset=utf8'
fi
[ $FS = xfs ] && OP+=',attr2,inode64,logbufs=8,logbsize=32k,noquota'
[ $FS = f2fs ] && OP+=',background_gc=on,no_heap,inline_xattr,inline_data,inline_dentry,flush_merge,extent_cache,mode=adaptive,active_logs=6,alloc_mode=reuse,checkpoint_merge,fsync_mode=posix,discard_unit=block,memory=normal'

yes=$(dialog --stdout --title "Synchronization Backup $1" \
        --yesno "This will backup files from\n/mnt/$SOURCE to $partition (/mnt/music_bk)." 0 0) || exit 1; clear
 
echo -e "Synchronization backup /mnt/$SOURCE to ${partition}${delmsg}."
mount -t $FS -m -o $OP $partition /mnt/music_bk
nocache rsync -avh $DEL --progress /mnt/$SOURCE/. /mnt/music_bk/.
[[ $options =~ D ]] && umount /mnt/music_bk