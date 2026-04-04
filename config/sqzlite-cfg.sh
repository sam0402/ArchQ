#!/bin/bash
# squeezelite configuration helper

CONFIG='/etc/squeezelite.conf'
TITLE="ArchQ Squeezelite $1"

# Available packages indexed by dialog option: [0]=PCM-new [1]=DSD-new [2]=PCM-old [3]=DSD-old
PKG_VER='1.9.8.1317'
PKGS=("${PKG_VER}-21" "${PKG_VER}-22" "${PKG_VER}-11" "${PKG_VER}-12")

die() { echo "Error: $*" >&2; exit 1; }

# Read a config value; strips -X flag prefix; returns "" if commented/absent
cfg_get() {
    local key=$1 line val
    line=$(grep -E "^${key}=" "$CONFIG" | tail -1) || return
    val="${line#*=\"}"  # strip KEY="
    val="${val%\"}"     # strip trailing "
    val="${val#-? }"    # strip -X flag prefix (e.g. "-n ")
    echo "$val"
}

# Write a config entry; if val is empty, comment it out
cfg_set() {
    local key=$1 flag=$2 val=$3
    if [[ -z "$val" ]]; then
        sed -i "s|^#\?${key}=\"${flag}.*|#${key}=\"${flag} \"|" "$CONFIG"
    else
        sed -i "s|^#\?${key}=\"${flag}.*|${key}=\"${flag} ${val}\"|" "$CONFIG"
    fi
}

#--- Version selection ---
ver=$(pacman -Q squeezelite 2>/dev/null | awk '{print $2}') \
    || die "squeezelite not installed"

option=$(dialog --stdout --title "$TITLE" \
    --menu "Select version:" 7 0 0 \
    0 "PCM" 1 "DSD") || exit 1
clear

target="${PKGS[$option]}"
if [[ "$ver" != "$target" ]]; then
    pkg_file="/tmp/squeezelite-${target}-x86_64.pkg.tar.zst"
    wget -P /tmp "https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/squeezelite-${target}-x86_64.pkg.tar.zst"
    pacman -U --noconfirm "$pkg_file"
    ver=$(pacman -Q squeezelite | awk '{print $2}')
fi

# Derive display label from pkgrel
case "${ver##*-}" in
    21|11) ver_label="${PKG_VER}-pcm" ;;
    22|12) ver_label="${PKG_VER}-dsd" ;;
    *)     ver_label="$ver" ;;
esac

#--- Device selection ---
mapfile -t dev_list < <(aplay -L 2>/dev/null | grep ':')
if [[ ${#dev_list[@]} -eq 0 ]]; then
    dialog --title "$TITLE" --msgbox "No Sound Device" 7 30
    exit 1
fi

devs=('hw:0,0' '　')
for d in "${dev_list[@]}"; do
    devs+=("$d" '　')
done

device=$(dialog --stdout --title "ArchQ Squeezelite ${ver_label}" \
    --menu "Output device" 7 0 0 "${devs[@]}") || exit 1
clear
sed -i "s|^AUDIO_DEV=\"-o .*|AUDIO_DEV=\"-o ${device}\"|" "$CONFIG"

#--- Load current settings ---
NAME=$(cfg_get NAME)
ALSA_PARAMS=$(cfg_get ALSA_PARAMS)
BUFFER=$(cfg_get BUFFER)
CODEC=$(cfg_get CODEC)
PRIORITY=$(cfg_get PRIORITY)
MAX_RATE=$(cfg_get MAX_RATE)
UPSAMPLE=$(cfg_get UPSAMPLE)
MAC=$(cfg_get MAC)
SERVER_IP=$(cfg_get SERVER_IP)
DOP=$(cfg_get DOP)
VOLUME=$(cfg_get VOLUME)

#--- DSD adjustments ---
INFO=''
if [[ "$ver_label" == *dsd* ]]; then
    [[ -z "$DOP" ]] && DOP='0:u32be'
    [[ "$CODEC" != *dsd* ]] && CODEC="${CODEC:+${CODEC},}dsd"
    INFO='\nDSD format: dop, u8, u16le, u16be, u32le, u32be'
else
    DOP=''
    CODEC="${CODEC%,dsd}"
fi

#--- Settings form ---
mapfile -t opts < <(dialog --stdout \
    --title "ArchQ Squeezelite ${ver_label}" --ok-label "Ok" \
    --form "Modify settings  (leave blank to disable)${INFO}" 0 60 0 \
    "Name of Player"      1 1  "$NAME"        1 25 60 0 \
    "ALSA setting"        2 1  "$ALSA_PARAMS" 2 25 60 0 \
    "Buffer Size"         3 1  "$BUFFER"      3 25 60 0 \
    "Restrict codec"      4 1  "$CODEC"       4 25 60 0 \
    "Priority"            5 1  "$PRIORITY"    5 25 60 0 \
    "Max Sample rate"     6 1  "$MAX_RATE"    6 25 60 0 \
    "Upsampling"          7 1  "$UPSAMPLE"    7 25 60 0 \
    "MAC address"         8 1  "$MAC"         8 25 60 0 \
    "LMS/Slim server IP"  9 1  "$SERVER_IP"   9 25 60 0 \
    "DSD/DoP format"     10 1  "$DOP"        10 25 60 0 \
    "ALSA volume control" 11 1  "$VOLUME"    11 25 60 0) || exit 1
clear

#--- Save settings ---
cfg_set NAME        -n "${opts[0]}"
cfg_set ALSA_PARAMS -a "${opts[1]}"
cfg_set BUFFER      -b "${opts[2]}"
cfg_set CODEC       -c "${opts[3]}"
cfg_set PRIORITY    -p "${opts[4]}"
cfg_set MAX_RATE    -r "${opts[5]}"
cfg_set UPSAMPLE    -R "${opts[6]}"
cfg_set MAC         -m "${opts[7]}"
cfg_set SERVER_IP   -s "${opts[8]}"
cfg_set DOP         -D "${opts[9]}"
cfg_set VOLUME      -V "${opts[10]}"

echo "$CONFIG updated."
systemctl restart squeezelite
echo "Squeezelite restarted."
