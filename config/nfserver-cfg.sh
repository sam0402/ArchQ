#!/bin/bash
config='/etc/exports'
WK=$(dialog --stdout --title "ArchQ $1" \
            --menu "NFS Server share" 7 0 0 A "Add" M "Modify" D "Delete") || exit 1; clear

if ! pacman -Q linux-Qrip >/dev/null 2>&1; then
    kver=$(pacman -Q | grep linux-Q | grep -v headers | awk 'NR==1{print $2}')
    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/kernel/linux-Qrip-${kver}-x86_64.pkg.tar.zst
    pacman -U --noconfirm /root/linux-Qrip-${kver}-x86_64.pkg.tar.zst
    yes | pacman -Scc >/dev/null 2>&1
fi

case $WK in
    A)
        ethers=$(ip -o link show | awk '{print $2,$9}' | grep '^en' | sed 's/://')
        ifport=$(echo $ethers | cut -d' ' -f1)
        if [ $(echo $ethers | wc -w) -gt 2 ]; then
            ifport=$(dialog --stdout --title "ArchQ $1" \
                    --menu "Select ethernet device" 7 0 0 ${ethers}) || exit 1; clear
        fi
        ifnetwk=$(ip route list | grep -v default | grep $ifport | cut -d' ' -f1)
        options=$(dialog --stdout \
            --title "ArchQ $1" \
            --ok-label "Ok" \
            --form "Add NFS share" 0 32 0 \
            "Directory" 1 1   ""           1 12 32 0 \
            "Network"   2 1   "$ifnetwk"   2 12 32 0 \
            "Options"   3 1   "rw,sync"    3 12 32 0) || exit 1
        clear

        DIR=$(echo $options | cut -d' ' -f1)
        NWK=$(echo $options | cut -d' ' -f2)
        OPT=$(echo $options | cut -d' ' -f3)

        echo -e "${DIR}\t${NWK}($OPT)" >>$config
    ;;
    
    D)
        n=1; MENU=''
        while read line; do
            if echo $line | grep -v '#'; then
                DIRs=$(echo $line | cut -d' ' -f1)
                MENU=${MENU}$n' '$DIRs' '
            fi
        n=`expr $n + 1`
        done < $config

        if [ -n "$MENU" ]; then
            options=$(dialog --stdout \
                    --title "ArchQ $1" \
                    --ok-label "Ok" \
                    --menu "Delete NFS shared" 7 0 0 $MENU) || exit 1; clear
            sed -i ''"$options"'d' $config
        else
            dialog --stdout --title "ArchQ $1" --msgbox "\n  No NFS Server exporting data." 7 25
        fi
    ;;

    M)
        n=1
        while read line; do
            if echo $line | grep -v '#'; then       
                DIRs=$(echo $line | cut -d' ' -f1)
                NWKs=$(echo $line | cut -d' ' -f2 | cut -d'(' -f1)
                OPTs=$(echo $line | cut -d' ' -f2 | cut -d'(' -f2 | sed 's/)//')
                options=$(dialog --stdout \
                        --title "ArchQ $1" \
                        --ok-label "Ok" \
                        --form "Modify NFS shared" 0 32 0 \
                    "Directory" 1 1 "$DIRs" 1 12 32 0 \
                    "Network"   2 1 "$NWKs" 2 12 32 0 \
                    "Options"   3 1 "$OPTs" 3 12 32 0) || exit 1; clear

                DIR=$(echo $options | cut -d' ' -f1)
                NWK=$(echo $options | cut -d' ' -f2)
                OPT=$(echo $options | cut -d' ' -f3)
                DIR=$(echo $DIR | sed 's"/"\\\/"g')
                DIRs=$(echo $DIRs | sed 's"/"\\\/"g')
                NWK=$(echo $NWK | sed 's"/"\\\/"g')
                NWKs=$(echo $NWKs | sed 's"/"\\\/"g')
                sed -i ''"$n"'s/'"$DIRs"'/'"$DIR"'/;s/'"$NWKs"'/'"$NWK"'/;s/'"$OPTs"'/'"$OPT"'/' $config
            fi
        n=`expr $n + 1`
        done < $config
    ;;
esac
#
systemctl enable --now nfs-server
exportfs -arv