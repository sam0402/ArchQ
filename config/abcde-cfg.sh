#!/bin/bash
config='/etc/abcde.conf'
if [ ! -f $config ]; then
    pacman -S --noconfirm glyr cdparanoia libdiscid atomicparsley make
    pacman -Syu --noconfirm

    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/abcde-2.9.3-5-any.pkg.tar.zst
    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/cd-discid-1.4-3-x86_64.pkg.tar.zst
    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/rc-local-4-1-any.pkg.tar.zst
    pacman -U --noconfirm /root/cd-discid-1.4-3-x86_64.pkg.tar.zst /root/abcde-2.9.3-5-any.pkg.tar.zst /root/rc-local-4-1-any.pkg.tar.zst
    curl -sL /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/abcde.conf >/etc/abcde.conf
    echo 'yes' | cpan -fi MusicBrainz::DiscID WebService::MusicBrainz

    sed -i '$d' /etc/rc.local
cat >>/etc/rc.local <<EOF 
[ \$(uname -r | awk -F - '{print \$3}') = 'Qrip' ] && \\
    systemctl stop roonserver squeezelite mpd logitechmediaserver squeezelite shairport-sync 2> /dev/null
exit 0
EOF
fi

while read line; do
    eval $(grep '=' | grep -v '#')
done < $config

options=$(dialog --stdout \
    --title "abcde" \
    --ok-label "Ok" \
    --form "Modify settings" 0 40 0 \
    "Output directory"  1 1   "${OUTPUTDIR}"    1 18 40 0 \
    "Type (wav/flac)"   2 1   "${OUTPUTTYPE}"   2 18 40 0 \
    "Read speed"        3 1   "${CDSPEEDVALUE}" 3 18 40 0 \
    "Read offset"       4 1   "$OFFSET"         4 18 40 0 \
    "Eject CD (y/n)"    5 1   "$EJECTCD"        5 18 40 0) || exit 1
clear

OUTPUTDIR=$(echo $options |  awk '//{print $1 }')
OUTPUTTYPE=$(echo $options |  awk '//{print $2 }')
OFFSET=$(echo $options |  awk '//{print $3 }')
CDSPEEDVALUE=$(echo $options |  awk '//{print $4 }')
EJECTCD=$(echo $options |  awk '//{print $5 }')

[ -z $OUTPUTDIR ] && echo "Fail! Output directory is null." && exit 1
[ -z $OUTPUTTYPE ] && echo "Fail! Output type is null." && exit 1
[ -z $OFFSET ] && echo "Fail! Read offset is null." && exit 1
[ -z $CDSPEEDVALUE ] && echo "Fail! Read offset is null." && exit 1
[ -z $EJECTCD ] && echo "Fail! Eject CD is null." && exit 1

OUTPUTDIR=$(echo $OUTPUTDIR | sed 's"/"\\\/"g')
sed -i 's/^#\?OUTPUTDIR=".*/OUTPUTDIR="'"$OUTPUTDIR"'"/' $config
sed -i 's/^#\?OUTPUTTYPE=".*/OUTPUTTYPE="'"$OUTPUTTYPE"'"/' $config
sed -i 's/^#\?OFFSET=".*/OFFSET="'"$OFFSET"'"/' $config
sed -i 's/^#\?CDSPEEDVALUE=".*/CDSPEEDVALUE="'"$CDSPEEDVALUE"'"/' $config
sed -i 's/^#\?EJECTCD=.*/EJECTCD='"$EJECTCD"'/' $config
