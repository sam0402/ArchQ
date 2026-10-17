#!/bin/bash
# ==============================================================================
# ArchQ MPD Configuration Utility
# 功能：
#   1. 設定 MPD 用戶端 (myMPD, RompR, Cantata, Ncmpcpp, Multi-user)
#   2. 設定音訊可選輸出 (Multi-room / AirPlay, Multi-player / 分區, Http Stream)
#   3. 設定音訊緩衝區大小 (audio_buffer_size)
#   4. 設定 PcmNet 接收端 IP (host) 與音樂目錄路徑 (music_directory)
# ==============================================================================

config='/etc/mpd.conf'
user=$(awk -F: '$3 == 1000 {print $1}' /etc/passwd)
user=${user:-sam}

# ------------------------------------------------------------------------------
# 輔助函式：切換 include_optional 設定項
# ------------------------------------------------------------------------------
set_include() {
    local target_file="$1"
    local state="$2"  # on 或 off
    local directive="include_optional \"$target_file\""

    if [ "$state" = "on" ]; then
        if grep -q "$target_file" "$config"; then
            sed -i "s|^[[:space:]]*#\?[[:space:]]*include_optional[[:space:]]\+\"$target_file\"|$directive|" "$config"
        else
            echo "$directive" >> "$config"
        fi
    else
        if grep -q "$target_file" "$config"; then
            sed -i "s|^[[:space:]]*include_optional[[:space:]]\+\"$target_file\"|#$directive|" "$config"
        fi
    fi
}

# ------------------------------------------------------------------------------
# 輔助函式：音量控制設定 (none / software / hardware)
# ------------------------------------------------------------------------------
vol_ctrl() {
    local target="$2"
    local v_none='off' v_soft='off' v_hard='off'
    case $(grep -E '^[[:space:]]*mixer_type[[:space:]]+' "$target" | cut -d'"' -f2) in
        software) v_soft=on ;;
        hardware) v_hard=on ;;
        *)        v_none=on ;;
    esac

    local volume
    volume=$(dialog --stdout \
        --title "ArchQ MPD" \
        --radiolist "$1 volume control" 7 0 0 \
        none '　' $v_none \
        software '　' $v_soft \
        hardware '　' $v_hard) || exit 1
    clear
    sed -i -E "s/^[[:space:]]*#?[[:space:]]*mixer_type[[:space:]]+\"[^\"]*\"/mixer_type\t\"$volume\"/" "$target"
}

# ------------------------------------------------------------------------------
# 輔助函式：瀏覽現有的 Multi-player (Owntone 分區) 連接埠清單
# ------------------------------------------------------------------------------
brow_mtp() {
    local menu="Name"$'\t\t:'"Ctrl-port\n"
    local found=0
    for file in /etc/owntone-*.conf; do
        [ -f "$file" ] || continue
        found=1
        local port
        port=$(grep -E '^[[:space:]]*port[[:space:]]+' "$file" | awk '{print $3}')
        local filename="${file##*/}"
        filename="${filename:8:-5}"
        menu+="${filename@u}"$'\t:'"$port"$'\n'
    done

    [ $found -eq 0 ] && menu="No multi-player configured."
    dialog --stdout --title "ArchQ MPD" --msgbox "$menu" 10 30 || exit 1
    clear
}

# ==============================================================================
# 第一步：選擇 MPD 用戶端 (若安裝 mpd-stream 則可設定 Multi-user)
# ==============================================================================
client=''
if pacman -Q mpd-stream >/dev/null 2>&1; then
    client=$(dialog --stdout --title "ArchQ MPD" --menu "Setting Multi user?" 7 0 0 N "No" U "Yes") || exit 1
    clear
fi

case $client in
    U)
        # Multi-user (透過 mpd-proxy 分配多組 MPD 控制與串流連接埠)
        new=$(ls /etc/systemd/system/multi-user.target.wants/ 2>/dev/null | grep 'mpd-proxy@' | grep -oP '(?<=@)[0-9]+' |
            awk 'BEGIN{max=0} {if($1>max) max=$1} END{print max+1}')
        new=${new:-1}
        port="800${new}"

        mu_menu=(A "Add")
        ls /etc/systemd/system/multi-user.target.wants/mpd-proxy@*.service >/dev/null 2>&1 && mu_menu+=(R "Remove")

        wk=$(dialog --stdout --title "ArchQ MPD" --menu "Multi User" 7 0 0 "${mu_menu[@]}") || exit 1
        clear

        case $wk in
            A)
                # 新增使用者並建立專屬串流設定檔
                user_name=$(dialog --stdout --title "ArchQ MPD User" --inputbox "Add user name" 0 25) || exit 1
                clear
                if [ -n "$user_name" ]; then
                    cp /etc/mpd.d/httpd.out "/etc/mpd.d/${port}.out"
                    sed -i "s/mp3/$port/;s/port.*\"/port\t\"$port\"/" "/etc/mpd.d/${port}.out"
                    grep -q "${port}" "$config" || echo "include_optional \"mpd.d/${port}.out\"" >> "$config"
                    systemctl enable --now "mpd-proxy@${new}${user_name}"
                    echo "$user_name's MPD control port: 660$new; Stream port: $port"
                fi
                ;;
            R)
                # 移除既有使用者
                users=()
                while read -r u; do
                    [ -n "$u" ] && users+=("$u" "")
                done <<< $(ls /etc/systemd/system/multi-user.target.wants/ 2>/dev/null | grep '^mpd-proxy@.*\.service$' | grep -oP '(?<=@).*(?=\.service)')

                if [ ${#users[@]} -gt 0 ]; then
                    rm_user=$(dialog --stdout --title "ArchQ MPD User" --menu "Select user to remove" 7 0 0 "${users[@]}") || exit 1
                    clear
                    sed -i "/800${rm_user:0:1}/d" "$config"
                    systemctl disable --now "mpd-proxy@${rm_user}"
                    rm -f "/etc/mpd.d/800${rm_user:0:1}.out"
                    echo "MPD User ${rm_user:1} is removed."
                else
                    dialog --stdout --title "ArchQ MPD User" --msgbox "No multi-user to remove." 7 30
                fi
                ;;
        esac
        ;;
    *)
        ;;
esac

# ==============================================================================
# 第二步：選取額外音訊輸出 (Multi-room, Http Stream, Multi-player)
# ==============================================================================
m0=off; h0=off
grep -E '^[[:space:]]*include_optional[[:space:]]+"mpd.d/owntone.out"' "$config" >/dev/null 2>&1 && m0=on
grep -E '^[[:space:]]*include_optional[[:space:]]+"mpd.d/httpd.out"' "$config" >/dev/null 2>&1 && h0=on

output_menu=()
if pacman -Q mympd >/dev/null 2>&1 || [ "$client" = "M" ]; then
    p0=off
    grep -E '^[[:space:]]*include_optional[[:space:]]+"mpd.d/mtp_' "$config" >/dev/null 2>&1 && p0=on
    output_menu+=(P "Multi-player" "$p0")
fi

# 精簡版套件 (flcnet/pcmnet/qbznet/dsdnet/ul/wav/qobuz) 移除 fifo/httpd，不提供 Multi-room 與 Http Stream
if ! pacman -Q mpd-flcnet >/dev/null 2>&1 && ! pacman -Q mpd-pcmnet >/dev/null 2>&1 && \
   ! pacman -Q mpd-qbznet >/dev/null 2>&1 && ! pacman -Q mpd-dsdnet >/dev/null 2>&1 && \
   ! pacman -Q mpd-ul >/dev/null 2>&1 && ! pacman -Q mpd-wav >/dev/null 2>&1 && \
   ! pacman -Q mpd-qobuz >/dev/null 2>&1; then
    output_menu+=(M "Multi-room" "$m0" H "Http Stream:9000" "$h0")
fi

m1=off; p1=off; h1=off
if [ ${#output_menu[@]} -gt 0 ]; then
    selected_outputs=$(dialog --stdout --title "ArchQ MPD" --checklist "Output method" 7 0 0 "${output_menu[@]}") || exit 1
    clear

    [[ "$selected_outputs" =~ "M" ]] && m1=on
    [[ "$selected_outputs" =~ "P" ]] && p1=on
    [[ "$selected_outputs" =~ "H" ]] && h1=on
fi

# ------------------------------------------------------------------------------
# 2-1. AirPlay Multi-room (Owntone FIFO 輸出)
# ------------------------------------------------------------------------------
if [ "$m1" = "on" ]; then
    [ -d /var/lib/mpd/fifo ] || install -o mpd -g mpd -m 755 -d /var/lib/mpd/fifo
    set_include "mpd.d/owntone.out" on
    systemctl enable --now avahi-daemon.socket owntone
else
    set_include "mpd.d/owntone.out" off
    systemctl disable --now owntone avahi-daemon.socket
fi

# ------------------------------------------------------------------------------
# 2-2. Multi-player 多分區輸出 (需支援 partition 的 mpd-stream 套件)
# ------------------------------------------------------------------------------
if [ "$p1" = "on" ]; then
    if ! pacman -Q mpd-stream >/dev/null 2>&1; then
        wget -qP /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd-stream-0.23.18-4-x86_64.pkg.tar.zst || \
        wget -qP /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd-stream-0.23.14-12-x86_64.pkg.tar.zst
        pacman -U --noconfirm /tmp/mpd-stream-*.pkg.tar.zst
    fi
    sed -i 's/^[[:space:]]*#\?[[:space:]]*include_optional "mpd.d\/mtp_/include_optional "mpd.d\/mtp_/' "$config"

    mtp_choice=$(dialog --stdout --title "ArchQ MPD" --menu "Player(Partition)" 7 0 0 \
        B "Browse" A "Add" R "Remove") || exit 1
    clear

    case $mtp_choice in
        B)
            brow_mtp
            ;;
        A)
            # 新增分區輸出與對應的 Owntone 獨立服務
            mtp_name=$(dialog --stdout --title "ArchQ" --inputbox "Add player(partition)" 0 0) || exit 1
            clear
            if [ -n "$mtp_name" ]; then
                name_u="${mtp_name@u}"
                mtp_file="/etc/mpd.d/mtp_${name_u}.out"
                echo "include_optional \"mpd.d/mtp_${name_u}.out\"" >> "$config"

                cat > "$mtp_file" <<EOF
audio_output {
	type	"fifo"
	name	"${name_u}"
	path	"/var/lib/mpd/${name_u}/air"
	format	"44100:16:2"
}
EOF
                [ -d "/var/lib/mpd/${name_u}" ] || install -o mpd -g mpd -m 755 -d "/var/lib/mpd/${name_u}"

                # 確保 instantiated service 範本存在
                if [ ! -f /etc/systemd/system/owntone@.service ] && [ -f /usr/lib/systemd/system/owntone.service ]; then
                    sed 's|ExecStart=/usr/bin/owntone -f|ExecStart=/usr/bin/owntone -f -c /etc/owntone-%i.conf|' \
                        /usr/lib/systemd/system/owntone.service > /etc/systemd/system/owntone@.service
                    systemctl daemon-reload
                fi
                ln -sf "/etc/systemd/system/owntone@.service" "/etc/systemd/system/owntone@${name_u}.service"

                # 搜尋現有 Owntone 設定檔以遞增 port
                max_port=3689
                for f in /etc/owntone-*.conf; do
                    [ -f "$f" ] || continue
                    p=$(grep -E '^[[:space:]]*port[[:space:]]+' "$f" | awk '{print $3}')
                    if [[ "$p" =~ ^[0-9]+$ ]] && (( p > max_port )); then
                        max_port=$p
                    fi
                done

                cat > "/etc/owntone-${name_u}.conf" <<EOF
general {
	uid = "owntone"
	loglevel = fatal
	ipv6 = no
	cache_daap_threshold = 1000
	speaker_autoselect = no
	high_resolution_clock = yes
}

library {
	port = $((max_port + 1))
	directories = { "/var/lib/mpd/${name_u}" }
	follow_symlinks = false
}
EOF
                brow_mtp
                systemctl enable --now avahi-daemon.socket "owntone@${name_u}"
            fi
            ;;
        R)
            # 移除指定分區輸出
            del_menu=()
            while read -r line; do
                [ -n "$line" ] && del_menu+=("$line" "")
            done <<< $(grep -oP '(?<=mtp_)[^.]+(?=\.out)' "$config" 2>/dev/null)

            if [ ${#del_menu[@]} -gt 0 ]; then
                rm_target=$(dialog --stdout --title "ArchQ MPD" --menu "Remove player(partition)" 7 0 0 "${del_menu[@]}") || exit 1
                clear
                systemctl disable --now "owntone@${rm_target}"
                sed -i "/mtp_${rm_target}/d" "$config"
                rm -f "/etc/mpd.d/mtp_${rm_target}.out" "/etc/owntone-${rm_target}.conf" \
                      "/etc/systemd/system/owntone@${rm_target}.service" "/etc/systemd/system/owntone@${rm_target}"
                brow_mtp
            else
                dialog --stdout --title "ArchQ MPD" --msgbox "No player to remove." 7 30
            fi
            ;;
    esac
fi

# ------------------------------------------------------------------------------
# 2-3. Httpd stream 輸出與編碼器設定 (Stream.mp3 / Stream.flac)
# ------------------------------------------------------------------------------
if [ "$h1" = "on" ]; then
    ht_conf='/etc/mpd.d/httpd.out'
    set_include "mpd.d/httpd.out" on

    http_flac=off; http_wave=off; http_lame=off
    if [ -f "$ht_conf" ]; then
        enc=$(grep -E '^[[:space:]]*encoder[[:space:]]+' "$ht_conf" | cut -d'"' -f2)
        case "$enc" in
            lame|mp3) http_lame=on ;;
            wave)     http_wave=on ;;
            *)        http_flac=on ;;
        esac
    else
        http_flac=on
    fi

    # 依套件支援之編碼器動態組合選單
    codec_menu=()
    if pacman -Q mpd-ffmpeg >/dev/null 2>&1 || pacman -Q mpd-stream >/dev/null 2>&1; then
        codec_menu=(mp3 "　" "$http_lame" flac "　" "$http_flac" wave "　" "$http_wave")
    elif pacman -Q mpd-radio >/dev/null 2>&1 || pacman -Q mpd-sam >/dev/null 2>&1; then
        codec_menu=(mp3 "　" "$http_lame" flac "　" "$http_flac")
    elif pacman -Q mpd-light >/dev/null 2>&1; then
        codec_menu=(flac "　" "on")
    else
        codec_menu=(mp3 "　" "$http_lame" flac "　" "$http_flac")
    fi

    encoder=$(dialog --stdout --title "ArchQ MPD" --radiolist "Http:9000 codec" 7 0 0 "${codec_menu[@]}") || exit 1
    clear

    if [ -f "$ht_conf" ]; then
        sed -i "s/^[[:space:]]*name[[:space:]]\+\"[^\"]*\"/\tname\t\t\"Stream.$encoder\"/" "$ht_conf"
        [ "$encoder" = "mp3" ] && encoder="lame"
        sed -i "s/^[[:space:]]*encoder[[:space:]]\+\"[^\"]*\"/\tencoder\t\t\"$encoder\"/" "$ht_conf"
    fi
else
    set_include "mpd.d/httpd.out" off
fi

# ==============================================================================
# 第三步：設定緩衝區 (audio_buffer_size)、接收端 IP (host)、Bit Depth (format)、音樂目錄 (music_directory)
# ==============================================================================
mdir=$(grep -E '^[[:space:]]*music_directory[[:space:]]+' "$config" | cut -d'"' -f2)
mdir=${mdir#/mnt/}
mdir=${mdir#/}
mdir=${mdir:-music}

buffer=$(grep -E '^[[:space:]]*audio_buffer_size[[:space:]]+' "$config" | cut -d'"' -f2)
buffer=${buffer:-2048}

pcmrecvip=$(grep -E '^[[:space:]]*host[[:space:]]+' "$config" | cut -d'"' -f2)
[ -z "$pcmrecvip" ] && pcmrecvip=$(grep -E '^[[:space:]]*ip[[:space:]]+' "$config" | cut -d'"' -f2)
pcmrecvip=${pcmrecvip:-127.0.0.1}

bitdepth=$(grep -E '^[[:space:]]*format[[:space:]]+' "$config" | cut -d'"' -f2)
if [[ "$bitdepth" =~ : ]]; then
    bitdepth=$(echo "$bitdepth" | cut -d':' -f2)
fi

form_res=$(dialog --stdout --title "ArchQ MPD" --ok-label "Ok" --form "Buffer & Music directory" 0 40 0 \
    "Audio Buffer ≧128 " 1 1 "$buffer"    1 19 40 0 \
    "Pcmrecv IP"         2 1 "$pcmrecvip" 2 19 40 0 \
    "Bit Depth"          3 1 "$bitdepth"  3 19 40 0 \
    "Music Dir    /mnt/" 4 1 "$mdir"      4 19 40 0) || exit 1
clear

# 逐行讀取表單結果，防範空欄位位移
{
    read -r buffer
    read -r pcmrecvip
    read -r bitdepth
    read -r mdir
} <<< "$form_res"

buffer=${buffer:-2048}
pcmrecvip=${pcmrecvip:-127.0.0.1}
mdir=${mdir#/mnt/}
mdir=${mdir#/}
mdir=${mdir:-music}

# 3-1. 寫入 audio_buffer_size
sed -i -E "s/^[[:space:]]*#?[[:space:]]*audio_buffer_size[[:space:]]+\"[^\"]*\"/audio_buffer_size\t\"$buffer\"/" "$config"

# 3-2. 寫入 Pcmrecv IP (pcmnet 使用 host，相容舊版 slim 的 ip)
if grep -q -E '^[[:space:]]*#?[[:space:]]*host[[:space:]]+' "$config"; then
    sed -i -E "s/^[[:space:]]*#?[[:space:]]*host[[:space:]]+\"[^\"]*\"/    host        \"$pcmrecvip\"/" "$config"
elif grep -q -E '^[[:space:]]*#?[[:space:]]*ip[[:space:]]+' "$config"; then
    sed -i -E "s/^[[:space:]]*#?[[:space:]]*ip[[:space:]]+\"[^\"]*\"/\tip\t\t\"$pcmrecvip\"/" "$config"
fi

# 3-3. 寫入 Bit Depth (format，空白為註解)
if [ -n "$bitdepth" ]; then
    if [[ "$bitdepth" =~ : ]]; then
        fmt_val="$bitdepth"
    else
        fmt_val="*:${bitdepth}:*"
    fi
    if grep -q -E '^[[:space:]]*#?[[:space:]]*format[[:space:]]+' "$config"; then
        sed -i -E "s|^[[:space:]]*#?[[:space:]]*format[[:space:]]+.*|    format\t\"$fmt_val\"|" "$config"
    fi
else
    # 空白為註解
    sed -i -E "s|^[[:space:]]*format[[:space:]]+|#    format\t|" "$config"
fi

# 3-4. 寫入音樂目錄路徑
sed -i "s|^[[:space:]]*#\?[[:space:]]*music_directory.*|music_directory\t\"/mnt/$mdir\"|" "$config"

# 3-5. 同步更新 Blissify 音樂路徑
[ -f /etc/blissify.conf ] && sed -i "s/\"mpd_base_path\": \".*\"/\"mpd_base_path\": \"$mdir\"/" /etc/blissify.conf

# ==============================================================================
# 第四步：重啟 MPD 服務
# ==============================================================================
systemctl restart mpd
echo "MPD is configured and restarted."