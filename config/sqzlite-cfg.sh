#!/bin/bash
config='/etc/squeezelite.conf'

### Select squeezelite version
ver=$(pacman -Q squeezelite | awk -F ' ' '{print $2}')
inst=(1.9.8.1317-pcm 1.9.8.1317-dsd 2.0.0.1518-pcm 2.0.0.1518-dsd)
option=$(dialog --stdout --title "ArchQ Squeezelite $1" \
        --menu "Select: ${inst}" 7 0 0 \
        0 "1.9 PCM" 1 "1.9 DSD" 2 "2.0 PCM" 3 "2.0 DSD" \
        ) || exit 1; clear

ver=${ver/-[17]/-pcm}; ver=${ver/-[28]/-dsd}
if [ "${ver}" != ${inst[$option]} ]; then
    cpus=$(getconf _NPROCESSORS_ONLN)
    pacman -U --noconfirm <(curl -fsSL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/squeezelite-${inst[$option]}-x86_64.pkg.tar.zst)
    ver=$(pacman -Q squeezelite | awk -F ' ' '{print $2}')
    ver=${ver/-[17]/-pcm}; ver=${ver/-[28]/-dsd}
fi

## Select sound device
if [ ! $(aplay -L | grep ':') ]; then
    dialog --title "ArchQ Squeezelite $1" --msgbox "No Sound Device" 7 30
else
    devs='hw:0,0 　 '
    while read line; do
        devs+=${line}' 　 '
    done <<< $(aplay -L | grep ':')

    device=$(dialog --stdout \
            --title "ArchQ Squeezelite ${ver}" \
            --menu "Ouput device" 7 0 0 ${devs}) || exit 1; clear
    sed -i 's/^AUDIO_DEV="-o .*/AUDIO_DEV="-o '"$device"'"/' $config
fi

###
NAME='<null>'; ALSA_PARAMS='<null>'; BUFFER='<null>'; CODEC='<null>'; PRIORITY='<null>'; OPTIONS='<null>'
MAX_RATE='<null>'; UPSAMPLE='<null>'; MAC='<null>'; SERVER_IP='<null>'; VOLUME='<null>'

while read line; do
    eval $(grep -v '#' | sed 's/-. //')
done < $config

if [[ ${ver} =~ dsd ]]; then
    [ "$DOP" = '<null>' ] && DOP='0:u32be'
    echo $CODEC | grep -q dsd || CODEC=$CODEC',dsd'
    INFO="\nDSD format: dop, u8, u16le, u16be, u32le, u32be"
else
    DOP='<null>'
    CODEC=$(echo $CODEC | sed 's/,dsd//')
fi

options=$(dialog --stdout \
    --title "ArchQ Squeezelite ${ver}" --ok-label "Ok" \
    --form "Modify settings. Blank fills with <null>$INFO" 0 60 0 \
    "Name of Player"        1 1   "$NAME"          1 25 60 0 \
    "ALSA setting"          2 1   "$ALSA_PARAMS"   2 25 60 0 \
    "Buffer Size setting"   3 1   "$BUFFER"        3 25 60 0 \
    "Restrict codec setting" 4 1   "$CODEC"        4 25 60 0 \
    "Priority setting"      5 1   "$PRIORITY"      5 25 60 0 \
    "Max Sample rate"       6 1   "$MAX_RATE"      6 25 60 0 \
    "Upsampling setting"    7 1   "$UPSAMPLE"      7 25 60 0 \
    "MAC address"           8 1   "$MAC"           8 25 60 0 \
    "LMS ip"                9 1   "$SERVER_IP"     9 25 60 0 \
    "Device supports DSD/DoP"  10 1   "$DOP"      10 25 60 0 \
    "ALSA volume control"   11 1   "$VOLUME"      11 25 60 0 ) || exit 1; clear
    # "other Options"         12 1   "$OPTIONS"     12 25 60 0
NAME=$(echo $options | cut -d ' ' -f 1)
sed -i 's/^#\?NAME="-n .*/NAME="-n '"$NAME"'"/' $config

ALSA_PARAMS=$(echo $options | cut -d ' ' -f 2)
sed -i 's/^#\?ALSA_PARAMS="-a .*/ALSA_PARAMS="-a '"$ALSA_PARAMS"'"/' $config

BUFFER=$(echo $options | cut -d ' ' -f 3)
[ $BUFFER = '<null>' ] && sed -i 's/^BUFFER/#BUFFER/' $config || sed -i 's/^#\?BUFFER="-b .*/BUFFER="-b '"$BUFFER"'"/' $config

CODEC=$(echo $options | cut -d ' ' -f 4)
[ $CODEC = '<null>' ] && sed -i 's/^CODEC/#CODEC/' $config || sed -i 's/^#\?CODEC="-c .*/CODEC="-c '"$CODEC"'"/' $config

PRIORITY=$(echo $options | cut -d ' ' -f 5)
[ $PRIORITY = '<null>' ] && sed -i 's/^PRIORITY/#PRIORITY/' $config || sed -i 's/^#\?PRIORITY="-p .*/PRIORITY="-p '"$PRIORITY"'"/' $config

MAX_RATE=$(echo $options | cut -d ' ' -f 6)
[ $MAX_RATE = '<null>' ] && sed -i 's/^MAX_RATE/#MAX_RATE/' $config || sed -i 's/^#\?MAX_RATE="-r .*/MAX_RATE="-r '"$MAX_RATE"'"/' $config

UPSAMPLE=$(echo $options | cut -d ' ' -f 7)
[ $UPSAMPLE = '<null>' ] && sed -i 's/^UPSAMPLE/#UPSAMPLE/' $config || sed -i 's/^#\?UPSAMPLE="-R .*/UPSAMPLE="-R '"$UPSAMPLE"'"/' $config

MAC=$(echo $options | cut -d ' ' -f 8)
[ $MAC = '<null>' ] && sed -i 's/^MAC/#MAC/' $config || sed -i 's/^#\?MAC="-m .*/MAC="-m '"$MAC"'"/' $config

SERVER_IP=$(echo $options | cut -d ' ' -f 9)
[ $SERVER_IP = '<null>' ] && sed -i 's/^SERVER_IP/#SERVER_IP/' $config || sed -i 's/^#\?SERVER_IP="-s .*/SERVER_IP="-s '"$SERVER_IP"'"/' $config

DOP=$(echo $options | cut -d ' ' -f 10)
[ $DOP = '<null>' ] && sed -i 's/^DOP/#DOP/' $config || sed -i 's/^#\?DOP="-D .*/DOP="-D '"$DOP"'"/' $config

VOLUME=$(echo $options | cut -d ' ' -f 11)
[ $VOLUME = '<null>' ] && sed -i 's/^VOLUME/#VOLUME/' $config || sed -i 's/^#\?VOLUME="-V .*/VOLUME="-V '"$VOLUME"'"/' $config

# OPTIONS=$(echo $options | cut -d ' ' -f 12)
# [ $OPTIONS = '<null>' ] && sed -i 's/^OPTIONS/#OPTIONS/' $config || sed -i 's/^#\?OPTIONS="-W .*/OPTIONS="-W '"$OPTIONS"'"/' $config

echo $config is setting.
systemctl stop squeezelite
systemctl start squeezelite
echo Squeezelite is restarted.