#!/bin/bash
serpath='/usr/lib/systemd/system/'
service=("mpd" "lyrionmusicserver" "squeezelite" "shairport-sync" "owntone" "hqplayerd" "networkaudio")
nickname=("MPD" "LMS" "Squeezelite" "Airplay" "OwnTone" "HQPlayerEmbedded" "NAA")
# Remove only the mimalloc settings managed by this script, including the
# old service-wide preload. Leave unrelated service environment settings intact.
remove_mimalloc() {
    sed -i -E \
        -e '/^Environment="?LD_PRELOAD=\/usr\/lib\/libmimalloc\.so\.3\.5"?$/d' \
        -e '/^Environment="?MIMALLOC_ALLOW_LARGE_OS_PAGES=[^" ]*"?$/d' \
        -e '/^Environment="?MIMALLOC_EAGER_COMMIT_DELAY=[^" ]*"?$/d' \
        -e 's|^(ExecStart=)/usr/bin/env LD_PRELOAD=/usr/lib/libmimalloc\.so\.3\.5 |\1|' \
        "$1"
}

arrList=(); arrService=()
for ((i=0; i < ${#service[@]}; i++))
do
    if [ -f "${serpath}${service[$i]}.service" ]; then
        arrList+=(${nickname[$i]})
        arrService+=(${service[$i]})
    fi
done

menu='';
case $2 in
    datacache)
        for ((i=0; i < ${#arrList[@]}; i++))
        do
            menu+=$i' '${arrList[$i]}
            grep -q pagecache-management "${serpath}${arrService[$i]}.service" && menu+=' on ' || menu+=' off '
        done

        options=$(dialog --stdout --title "ArchQ $1" --checklist "Data cache OFF" 7 0 0 ${menu}) || exit 1; clear
        for ((i=0; i < ${#arrList[@]}; i++))
        do
            if ( echo $options | grep -q $i ); then
                remove_mimalloc "${serpath}${arrService[$i]}.service"
                grep -q pagecache-management "${serpath}${arrService[$i]}.service" || \
                sed -i 's|ExecStart=|ExecStart=/usr/bin/pagecache-management.sh |' "${serpath}${arrService[$i]}.service"
            else
                sed -i 's|ExecStart=/usr/bin/pagecache-management.sh |ExecStart=|' "${serpath}${arrService[$i]}.service"
            fi
        done
    ;;
    hugepages)
        if ! pacman -Q mimalloc >/dev/null 2>&1; then
            wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mimalloc-3.5.3-1-x86_64.pkg.tar.zst
            pacman -U --noconfirm /tmp/mimalloc-3.5.3-1-x86_64.pkg.tar.zst
        fi
        for ((i=0; i < ${#arrList[@]}; i++))
        do
            menu+=$i' '${arrList[$i]}
            grep -q MIMALLOC_ALLOW_LARGE_OS_PAGES "${serpath}${arrService[$i]}.service" && menu+=' on ' || menu+=' off '
        done

        options=$(dialog --stdout --title "ArchQ $1" --checklist "HugePages Enable" 7 0 0 ${menu}) || exit 1; clear
        for ((i=0; i < ${#arrList[@]}; i++))
        do
            if ( echo $options | grep -q $i ); then
                remove_mimalloc "${serpath}${arrService[$i]}.service"
                # Keep pre/post-start helpers on the system allocator.
                sed -i '/^\[Service\]$/a \
Environment="MIMALLOC_ALLOW_LARGE_OS_PAGES=1"\
Environment="MIMALLOC_EAGER_COMMIT_DELAY=0"' "${serpath}${arrService[$i]}.service"
                sed -i 's/^User=.*/User=root/' "${serpath}${arrService[$i]}.service"
                sed -i 's|^ExecStart=/usr/bin/pagecache-management.sh |ExecStart=|' "${serpath}${arrService[$i]}.service"
                sed -i 's|^ExecStart=\(.\)|ExecStart=/usr/bin/env LD_PRELOAD=/usr/lib/libmimalloc.so.3.5 \1|' "${serpath}${arrService[$i]}.service"
            else
                remove_mimalloc "${serpath}${arrService[$i]}.service"
            fi
        done
    ;;
esac
systemctl daemon-reload             