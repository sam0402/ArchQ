#!/bin/bash
config='/etc/fstab'
# [ -f /etc/samba/smb.conf ] || ( mkdir -p /etc/samba; touch /etc/samba/smb.conf)

WK=$(dialog --stdout --title "ArchQ $1" \
            --menu "SMB/CIFS mount point" 7 0 0 A "Add" M "Modify" D "Delete") || exit 1
clear
if [ $WK = A ]; then
    options=$(dialog --stdout \
        --title "Add SMB/CIFS mount point" \
        --ok-label "Ok" \
        --form "Mount setting. Blank fills with <null>" 0 42 0 \
        "Mount point /mnt/" 1 1 ""                  1 18 42 0 \
        "Share name"        2 1 "//192.168.1.x/share"    2 18 42 0 \
        "Username"          3 1 "<null>"                 3 18 42 0 \
        "Password"          4 1 "<null>"                 4 18 42 0 \
        "Options"           5 1 "ro,iocharset=utf8" 5 18 42 0) || exit 1
    clear

    MP=$(echo $options | cut -d ' ' -f 1)
    SN=$(echo $options | cut -d ' ' -f 2)
    UN=$(echo $options | cut -d ' ' -f 3)
    PW=$(echo $options | cut -d ' ' -f 4)
    OP=$(echo $options | cut -d ' ' -f 5)
    [ $UN = '<null>' ] && UN=''
    [ $PW = '<null>' ] && PW=''
    echo "${SN} /mnt/${MP} cifs username=$UN,password=$PW,_netdev,nofail,file_mode=0644,dir_mode=0755,$OP 0 0" >>$config
elif [ $WK = D ]; then
    n=1; MENU=''
    while read line; do
      if [[ $(echo $line | cut -d ' ' -f 3) = cifs ]]; then
            MPs=$(echo $line | cut -d ' ' -f 2 | cut -d '/' -f 3)
            MENU=${MENU}$n' /mnt/'$MPs' '
      fi
      n=`expr $n + 1`
    done < $config
    if [ -n "$MENU" ]; then
        options=$(dialog --stdout \
                --title "SMB/CIFS mount point" \
                --ok-label "Ok" \
                --menu "Delete" 7 0 0 $MENU) || exit 1
                clear
        sed -i ''"$options"'d' $config
    else
        dialog --stdout --title "ArchQ $1" --msgbox "\n  No SMB/CIFS data." 7 25
    fi
else
    n=1
    while read line; do
      if [[ $(echo $line | cut -d ' ' -f 3) = cifs ]]; then
            SNs=$(echo $line | cut -d ' ' -f 1)
            MPs=$(echo $line | cut -d ' ' -f 2 | cut -d '/' -f 3)
            UNs=$(echo $line | cut -d ' ' -f 4 | cut -d '=' -f 2 | cut -d ',' -f 1)
            [ ! $UNs ] && UNs='<null>'
            PWs=$(echo $line | cut -d ' ' -f 4 | cut -d '=' -f 3 | cut -d ',' -f 1)
            [ ! $PWs ] && PWs='<null>'
            OPs=$(echo $line | cut -d ' ' -f 4 | cut -d ',' -f 7-)
            options=$(dialog --stdout \
                    --title "SMB/CIFS mount point" \
                    --ok-label "Ok" \
                    --form "Mount setting. Blank fills with <null>" 0 42 0 \
                "Mount Point /mnt/" 1 1   "$MPs"        1 18 42 0 \
                "Share Name"        2 1   "$SNs"        2 18 42 0 \
                "Username"          3 1   "$UNs"        3 18 42 0 \
                "Password"          4 1   "$PWs"        4 18 42 0 \
                "Options"           5 1   "$OPs"        5 18 42 0) || exit 1
            clear

            MP=$(echo $options | cut -d ' ' -f 1)
            SN=$(echo $options | cut -d ' ' -f 2)
            UN=$(echo $options | cut -d ' ' -f 3)
            PW=$(echo $options | cut -d ' ' -f 4)
            OP=$(echo $options | cut -d ' ' -f 5)
            [ $UN = '<null>' ] && UN=''; [ $UNs = '<null>' ] && UNs=''
            [ $PW = '<null>' ] && PW=''; [ $PWs = '<null>' ] && PWs=''
            SN=$(echo $SN | sed 's"/"\\\/"g')
            SNs=$(echo $SNs | sed 's"/"\\\/"g')
            sed -i ''"$n"'s/'"$MPs"'/'"$MP"'/;s/'"$SNs"'/'"$SN"'/;s/'"$OPs"'/'"$OP"'/;s/'"name=$UNs"'/'"name=$UN"'/;s/'"word=$PWs"'/'"word=$PW"'/' $config
      fi  
      n=`expr $n + 1`
    done < $config
fi
systemctl daemon-reload