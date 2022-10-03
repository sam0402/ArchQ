#!/bin/bash
config='/etc/abcde.conf'
user=$(grep '1000' /etc/passwd | awk -F: '{print $1}')

if ! pacman -Q abcde >/dev/null 2>&1 ; then
    pacman -Sy --noconfirm archlinux-keyring
    pacman -Scc --noconfirm
    pacman -Syy --noconfirm
    pacman -S --noconfirm nano cdparanoia glyr imagemagick atomicparsley base-devel ffmpeg srt
    rm /root/*.pkg.tar.zst
    kver=$(pacman -Q | grep linux-Q | grep -v headers | awk 'NR==1{print $2}')
    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/kernel/linux-Qrip-${kver}-x86_64.pkg.tar.zst
    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/abcde-2.9.3-6-any.pkg.tar.zst
    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/cdparanoia-10.2-9-x86_64.pkg.tar.zst
    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/cd-discid-1.4-3-x86_64.pkg.tar.zst
    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/rc-local-4-1-any.pkg.tar.zst
    pacman -U --noconfirm /root/*.pkg.tar.zst
    grub-mkconfig -o /boot/grub/grub.cfg
    systemctl enable rc-local.service
    curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/config/abcde.conf >/etc/abcde.conf
    echo 'yes' | cpan install MusicBrainz::DiscID WebService::MusicBrainz
    curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/ls2cddb.sh >/usr/bin/ls2cddb.sh
    chmod +x /usr/bin/ls2cddb.sh

    sed -i '$d' /etc/rc.local
cat >>/etc/rc.local <<EOF
server="roonserver squeezelite mpd logitechmediaserver squeezelite shairport-sync"
if [ \$(uname -r | awk -F - '{print \$3}') = 'Qrip' ]; then
    for i in \$server; do   
        [ \$(systemctl status \$i 2>&1 | grep -c 'Started') = 1 ] && systemctl stop \$i 
    done
fi
exit 0
EOF
    usermod -aG optical $user
    echo "alias abcde='eject -t; abcde'" >>/home/$user/.bashrc
    echo "alias abcde='eject -t; abcde'" >>/root/.bashrc
fi

while read line; do
    eval $(grep '=' | grep -v '#')
done < $config

options=$(dialog --stdout \
    --title "abCDe ripper" \
    --ok-label "Ok" \
    --form "Modify settings" 0 40 0 \
    "Output directory"  1 1   "${OUTPUTDIR}"    1 18 40 0 \
    "Type (wav/flac)"   2 1   "${OUTPUTTYPE}"   2 18 40 0 \
    "Read offset"       3 1   "${OFFSET}"       3 18 40 0 \
    "Read speed"        4 1   "${CDSPEEDVALUE}" 4 18 40 0 \
    "Eject CD (y/n)"    5 1   "${EJECTCD}"      5 18 40 0 \
    "Close Tray (Sec)"  6 1  "${CLOSETRAY}" 6 18 40 0) || exit 1
clear

OUTPUTDIR=$(echo $options |  awk '//{print $1 }')
OUTPUTTYPE=$(echo $options |  awk '//{print $2 }')
OFFSET=$(echo $options |  awk '//{print $3 }')
CDSPEEDVALUE=$(echo $options |  awk '//{print $4 }')
EJECTCD=$(echo $options |  awk '//{print $5 }')
CLOSETRAY=$(echo $options |  awk '//{print $6 }')

[ -z $OUTPUTDIR ] && echo "Fail! Output directory is null." && exit 1
[ -z $OUTPUTTYPE ] && echo "Fail! Output type is null." && exit 1
[ -z $OFFSET ] && echo "Fail! Read offset is null." && exit 1
[ -z $CDSPEEDVALUE ] && echo "Fail! Read offset is null." && exit 1
[ -z $EJECTCD ] && echo "Fail! Eject CD is null." && exit 1
[ -z $CLOSETRAY ] && echo "Fail! Auto Close Tray is null." && exit 1

# umount ${OUTPUTDIR}
chown $user: ${OUTPUTDIR}
# mount ${OUTPUTDIR}
OUTPUTDIR=$(echo $OUTPUTDIR | sed 's"/"\\\/"g')
sed -i 's/^#\?OUTPUTDIR=".*/OUTPUTDIR="'"$OUTPUTDIR"'"/' $config
sed -i 's/^#\?OUTPUTTYPE=".*/OUTPUTTYPE="'"$OUTPUTTYPE"'"/' $config
sed -i 's/^#\?OFFSET=".*/OFFSET="'"$OFFSET"'"/' $config
sed -i 's/^#\?CDSPEEDVALUE=".*/CDSPEEDVALUE="'"$CDSPEEDVALUE"'"/' $config
sed -i 's/^#\?EJECTCD=.*/EJECTCD='"$EJECTCD"'/' $config
sed -i 's/^#\?CLOSETRAY=.*/CLOSETRAY='"$CLOSETRAY"'/' $config
