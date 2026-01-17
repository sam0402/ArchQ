#!/bin/bash
config='/etc/fstab'
WK=$(dialog --stdout --title "ArchQ $1" \
            --menu "NFS mount point" 7 0 0 A "Add" M "Modify" D "Delete" C "Cachefilesd" ) || exit 1; clear
case "$WK" in
  A)
    options=$(dialog --stdout \
        --title "Add NFS mount point" \
        --ok-label "Ok" \
        --form "Mount setting" 0 40 0 \
        "Mount Point /mnt/" 1 1   ""        1 18 40 0 \
        "IP Address"        2 1   ""        2 18 40 0 \
        "Share Name"        3 1   "/"        3 18 40 0 \
        "Options"           4 1   "vers=3"  4 18 40 0) || exit 1
    clear

    MP=$(echo $options | cut -d ' ' -f 1)
    IP=$(echo $options | cut -d ' ' -f 2)
    SN=$(echo $options | cut -d ' ' -f 3)
    OP=$(echo $options | cut -d ' ' -f 4)
    systemctl is-enabled cachefilesd >/dev/null 2>&1 && OP="${OP},fsc"

    echo "$IP:$SN /mnt/$MP nfs defaults,_netdev,addr=$IP,nolock,$OP 0 0" >>$config
    if ! pacman -Q nfs-utils >/dev/null 2>&1 ; then
        pacman -S --noconfirm nfs-utils
    fi
    ;;
  D)
    n=1; MENU=''
    while read line; do
      if [[ $(echo $line | cut -d ' ' -f 3) = nfs ]]; then
            MPs=$(echo $line | cut -d ' ' -f 2 | cut -d '/' -f 3)
            MENU=${MENU}$n' /mnt/'$MPs' '
      fi
      n=`expr $n + 1`
    done < $config
    if [ -n "$MENU" ]; then
        options=$(dialog --stdout \
                --title "NFS mount point" \
                --ok-label "Ok" \
                --menu "Delete" 7 0 0 $MENU) || exit 1
                clear
        sed -i ''"$options"'d' $config
    else
        dialog --stdout --title "ArchQ $1" --msgbox "\n  No NFS data." 7 25
    fi
    ;;
  M)
    n=1
    while read line; do
      if [[ $(echo $line | cut -d ' ' -f 3) = nfs ]]; then
            IPs=$(echo $line | cut -d ' ' -f 1 | cut -d ':' -f 1)
            SNs=$(echo $line | cut -d ' ' -f 1 | cut -d ':' -f 2)
            MPs=$(echo $line | cut -d ' ' -f 2 | cut -d '/' -f 3)
            OPs=$(echo $line | cut -d ' ' -f 4 | cut -d ',' -f 5)
            options=$(dialog --stdout \
                    --title "NFS mount point" \
                    --ok-label "Ok" \
                    --form "Mount setting" 0 40 0 \
                "Mount Point /mnt/" 1 1   "$MPs"        1 18 40 0 \
                "IP Address"        2 1   "$IPs"        2 18 40 0 \
                "Share Name"        3 1   "$SNs"        3 18 40 0 \
                "Options"           4 1   "$OPs"        4 18 40 0) || exit 1; clear

            MP=$(echo $options | cut -d ' ' -f 1)
            IP=$(echo $options | cut -d ' ' -f 2)
            SN=$(echo $options | cut -d ' ' -f 3)
            OP=$(echo $options | cut -d ' ' -f 4)
            SN=$(echo $SN | sed 's"/"\\\/"g')
            SNs=$(echo $SNs | sed 's"/"\\\/"g')
            sed -i ''"$n"'s/'"$IPs"'/'"$IP"'/g;s/'"$MPs"'/'"$MP"'/;s/'"$SNs"'/'"$SN"'/;s/'"$OPs"'/'"$OP"'/' $config
      fi  
      n=`expr $n + 1`
    done < $config
    ;;
    C)
    CACHE=$(dialog --stdout --title "ArchQ $1" \
            --menu "Cachefilesd setting" 7 0 0 E "Enable" D "Disable" ) || exit 1; clear
    case "$CACHE" in
      E)
        if ! pacman -Q cachefilesd >/dev/null 2>&1 ; then
            wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/cachefilesd-0.10.10-2-x86_64.pkg.tar.zst
            pacman -U --noconfirm /tmp/cachefilesd-0.10.10-2-x86_64.pkg.tar.zst
            curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/config/cachefilesd.conf >/etc/cachefilesd.conf
        fi
        systemctl enable --now cachefilesd
        n=1
        while read line; do
          if [[ $(echo $line | cut -d ' ' -f 3) = nfs ]]; then
                opts=$(echo $line | cut -d ' ' -f 4)
                [[ $opts =~ fsc ]] || sed -i ''"$n"'s/ nfs '"$opts"'/ nfs '"$opts"',fsc/' $config
          fi
          n=`expr $n + 1`
        done < $config
        ;;
      D)
        systemctl disable --now cachefilesd
        ;;
    esac
    ;;
esac
systemctl daemon-reload
