#!/bin/bash
# squeezelite configuration helper

CONFIG='/etc/squeezelite.conf'
ver=$(pacman -Q squeezelite | awk -F ' ' '{print $2}')

# Available packages indexed by dialog option: [0]=PCM-ALSA [1]=DSD-ALSA [2]=PCM-TinyALSA [3]=DSD-TinyALSA
PKG_VER='1.9.8.1317'
PKGS=("${PKG_VER}-31" "${PKG_VER}-32" "${PKG_VER}-61" "${PKG_VER}-62")
LABELS=("PCM ALSA" "DSD ALSA" "PCM TinyALSA" "DSD TinyALSA")

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
    local key=$1 flag=$2 val=$3 line escaped
    local pattern="^[[:space:]]*#?[[:space:]]*${1}="
    if [[ -z "$val" ]]; then
        line="#${key}=\"${flag} \""
    else
        line="${key}=\"${flag} ${val}\""
    fi
    if grep -Eq "$pattern" "$CONFIG"; then
        escaped=${line//\\/\\\\}
        escaped=${escaped//&/\\&}
        escaped=${escaped//|/\\|}
        sed -i -E "s|${pattern}.*|${escaped}|" "$CONFIG"
    else
        printf '%s\n' "$line" >> "$CONFIG"
    fi
}

#--- Version selection ---
ver=$(pacman -Q squeezelite 2>/dev/null | awk '{print $2}') \
    || die "squeezelite not installed"

case "${ver##*-}" in
    31) current_label="${LABELS[0]}" ;;
    32) current_label="${LABELS[1]}" ;;
    61) current_label="${LABELS[2]}" ;;
    62) current_label="${LABELS[3]}" ;;
    *)  current_label="$ver" ;;
esac
TITLE="ArchQ Squeezelite $1"
option=$(dialog --stdout --title "$TITLE" \
    --menu "Current: ${current_label}" 7 0 0 \
    0 "${LABELS[0]}" 1 "${LABELS[1]}" 2 "${LABELS[2]}" 3 "${LABELS[3]}") || exit 1
clear

target="${PKGS[$option]}"
ver_label="${LABELS[$option]}"
if ! pacman -Q tinyalsa-evl >/dev/null 2>&1 && [[ "$option" -ge 2 ]]; then
    wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/tinyalsa-evl-2.1-1-x86_64.pkg.tar.zst
    pacman -U --noconfirm /tmp/tinyalsa-evl-2.1-1-x86_64.pkg.tar.zst
fi
if [[ "$ver" != "$target" ]]; then
    pkg_file="/tmp/squeezelite-${target}-x86_64.pkg.tar.zst"
    wget -P /tmp "https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/squeezelite-${target}-x86_64.pkg.tar.zst"
    pacman -U --noconfirm "$pkg_file"
    ver=$(pacman -Q squeezelite | awk '{print $2}')
fi

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

device=$(dialog --stdout --title "Squeezelite ${ver_label}" \
    --menu "Output device" 7 0 0 "${devs[@]}") || exit 1
clear
sed -i "s|^AUDIO_DEV=\"-o .*|AUDIO_DEV=\"-o ${device}\"|" "$CONFIG"

#--- Load current settings ---
NAME=$(cfg_get NAME)
ALSA_PARAMS=$(cfg_get ALSA_PARAMS)
ALSA_PARAMS=${ALSA_PARAMS:-60:4::1}
BUFFER=$(cfg_get BUFFER)
BUFFER=${BUFFER:-20000:500000}
CODEC=$(cfg_get CODEC)
CODEC=${CODEC:-pcm}
PRIORITY=$(cfg_get PRIORITY)
PRIORITY=${PRIORITY:-95:80:65:50}
MAX_RATE=$(cfg_get MAX_RATE)
UPSAMPLE=$(cfg_get UPSAMPLE)
MAC=$(cfg_get MAC)
SERVER_IP=$(cfg_get SERVER_IP)
SERVER_IP=${SERVER_IP:-127.0.0.1}
DOP=$(cfg_get DOP)
DOP=${DOP:-0:u32be}
VOLUME=$(cfg_get VOLUME)

#--- DSD adjustments ---
INFO=''
if [[ "$ver_label" == *DSD* ]]; then
    [[ "$CODEC" != *dsd* ]] && CODEC="${CODEC:+${CODEC},}dsd"
    INFO='\nDSD format: dop, u8, u16le, u16be, u32le, u32be'
else
    DOP=''
    CODEC="${CODEC%,dsd}"
fi

#--- Settings form ---
mapfile -t opts < <(dialog --stdout \
    --title "Squeezelite ${ver_label}" --ok-label "Ok" \
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
