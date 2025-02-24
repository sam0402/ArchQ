#!/bin/bash
## modprobe brd rd_size=2621440 max_part=1 rd_nr=1
config='/etc/mpd.conf'
user=$(grep '1000' /etc/passwd | awk -F: '{print $1}')

### Volume Control none/software/hardware
vol_ctrl(){
    v_none='off'; v_soft='off'; v_hard='off'
    case $(grep 'mixer_type' $2 | cut -d'"' -f2) in
        none)
            v_none=on
            ;;
        software)
            v_soft=on
            ;;
        hardware)
            v_hard=on
            ;;
    esac
    volume=$(dialog --stdout \
        --title "ArchQ MPD" \
        --radiolist "$1 volume control" 7 0 0 \
        none '　' $v_none \
        software '　' $v_soft \
        hardware '　' $v_hard) || exit 1
    clear
    sed -i 's/mixer_type.*"/mixer_type\t"'"$volume"'"/' $2
}

brow_mtp(){
    MENU="Name"$'\t\t:'"Ctrl-port\n"
    for file in /etc/owntone-*.conf; do
        port=$(cat $file | grep port | cut -d ' ' -f 3)
        filename=${file##*/}; filename=${filename:8:-5}
        MENU=$MENU"${filename@u}"$'\t:'"$port"'\n'
    done
    dialog --stdout --title "ArchQ MPD" --msgbox "$MENU" 10 30 || exit 1; clear
}

### MPD client select
MENU=''
pacman -Q mympd >/dev/null 2>&1 && MENU+='M "myMPD :80" '
pacman -Q rompr >/dev/null 2>&1 && MENU+='R "RompR :6660" '
exec='dialog --stdout --title "ArchQ MPD" --menu "Select MPD client" 7 0 0 '$MENU'C "Cantata :8080" N "Ncmpcpp | Rigelian(iOS)"'
client=$(eval $exec)|| exit 1
clear
case $client in
    R)
        rm /etc/nginx/sites-enabled/cantata
        ln -s /etc/nginx/sites-available/rompr /etc/nginx/sites-enabled/rompr
        pacman -Q mympd >/dev/null 2>&1 && systemctl disable --now mympd php-fpm
        systemctl enable --now mpd nginx php-fpm avahi-daemon
        ;;
    M)
        pacman -Q mympd >/dev/null 2>&1 || (pacman -Sy --noconfirm archlinux-keyring mympd; yes | pacman -Scc >/dev/null 2>&1)
        systemctl disable --now nginx php-fpm
        systemctl enable --now mpd mympd
        ;;
    N)
        pacman -Q ncmpcpp >/dev/null 2>&1 || (pacman -Sy --noconfirm archlinux-keyring ncmpcpp; yes | pacman -Scc >/dev/null 2>&1)
        systemctl disable --now nginx php-fpm avahi-daemon
        pacman -Q mympd >/dev/null 2>&1 && systemctl disable --now mympd php-fpm
        ;;
    C)  
        rm /etc/nginx/sites-enabled/rompr
        ln -s /etc/nginx/sites-available/cantata /etc/nginx/sites-enabled/cantata
        pacman -Q mympd >/dev/null 2>&1 && systemctl disable --now mympd php-fpm
        systemctl enable --now mpd nginx
        ;;
    # U)
        # if [[ ! -d /usr/share/mpd ]]; then
        #     curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd_config.tar.gz | tar -xz -C /usr/share
        #     curl -L https://raw.githubusercontent.com/sam0402/ArchQ/main/config/mpdconf >/usr/bin/mpdconf
        #     chmod +x /usr/bin/mpdconf
        # fi
        # users=$(dialog --stdout --title "ArchQ MPD multi" --inputbox "Add users" 0 25 0) || exit 1; clear
        # num=$(grep 'mpd' /etc/passwd | wc -l)
        # users=$(( $users + $num - 1 ))
        # Httpd stream multi user
        # for ((i=$num; i <= $users; i++))
        # do
        #     useradd -mU "mpd$i"
        #     sh -c "echo mpd$i:mpd | chpasswd"
        #     mkdir -p /home/mpd$i/.config
        #     cp -a /usr/share/mpd /home/mpd$i/.config
        #     chown -R mpd$i: /home/mpd$i/.config
        #     port=$(( $(id -u mpd$i) + 5600 ))
        #     sed -i 's/port.*"/port\t"'"$port"'"/' /home/mpd$i/.config/mpd/mpd.conf
        #     sport=$(( $(id -u mpd$i) + 7000 ))
        #     sed -i 's/port.*"/port\t"'"$sport"'"/' /home/mpd$i/.config/mpd/httpd.out
        #     ln -s /usr/lib/systemd/user/mpd.service /usr/lib/systemd/user/mpd$i.service
        #     cp /usr/lib/systemd/user/mpd.socket /usr/lib/systemd/user/mpd$i.socket
        #     sed -i 's/ListenStream=6600/ListenStream='"$port"'/' /usr/lib/systemd/user/mpd$i.socket
        #     systemctl enable --now avahi-daemon
            # systemctl --user -M mpd$i@ enable mpd$i.socket
            # echo "User mpd$i's control port: $port, stream port: $sport"
        # done
        # echo "Use command 'mpdcfg mpd[$num-$users]' to configure."
        # exit 1
        # ;;
esac

# ### Select sound device
if [ ! $(aplay -L | grep ':') ]; then
    dialog --title "ArchQ MPD $1" --msgbox "No Sound Device" 7 30
else
    devs='hw:0,0 　 '
    while read line; do
        devs+=${line}' 　 '
    done <<< $(aplay -L | grep ':')

    device=$(dialog --stdout \
            --title "ArchQ MPD $1" \
            --menu "Ouput device" 7 0 0 ${devs}) || exit 1; clear
    sed -i 's/^#\?.* \?\tdevice.*"/\tdevice\t'"\"$device\""'/' $config
fi

### ALSA ###
## Volume Control
vol_ctrl ALSA $config

### Include audio output & Dop
m0=off; h0=off; d0=off
m1=off; h1=off; d1=off
MENU=''
if [ $client = M ]; then
    cat $config | grep 'mtp_' | grep -q '^i' && p0=on || p0=off
    p1=off
    MENU="P Multi-player $p0 "
fi
cat $config | grep owntone | grep -q '#' || m0=on 
cat $config | grep httpd | grep -q '#' || h0=on
cat $config | grep -q "#[[:space:]]dop" || d0=on
output=$(dialog --stdout --title "ArchQ MPD" \
        --checklist "Output method" 7 0 0 \
        M "Multi-room Play" $m0 $MENU \
        H "Http Stream:8000" $h0 \
        D "DSD over PCM" $d0 ) || exit 1; clear
[[ $output =~ M ]] && m1=on
[[ $output =~ P ]] && p1=on
[[ $output =~ H ]] && h1=on
[[ $output =~ D ]] && d1=on
## Airplay multi room on/off
if [[ $m1 == on ]]; then
    [[ -d /var/lib/mpd/fifo ]] || install -o mpd -g mpd -m 755 -d /var/lib/mpd/fifo
    sed -i 's/^#.\?include_optional "mpd.d\/owntone.out"/include_optional "mpd.d\/owntone.out"/' $config
    systemctl enable --now avahi-daemon.socket owntone
    # systemctl --user --now -M $user@ enable pipewire pipewire-pulse sinkdef
else
    sed -i 's/^include_optional "mpd.d\/owntone.out"/#include_optional "mpd.d\/owntone.out"/' $config
    systemctl  disable --now owntone avahi-daemon.socket
fi

if [[ $p1 == on ]]; then
    if ! pacman -Q mpd-stream >/dev/null 2>&1; then
        wget -qP /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd-stream-0.23.14-12-x86_64.pkg.tar.zst
        pacman -U --noconfirm /tmp/*.pkg.tar.zst
    fi
    sed -i 's/^#.\?include_optional "mpd.d\/mtp_/include_optional "mpd.d\/mtp_/' $config
    options=$(dialog --stdout --title "ArchQ MPD" --menu "Player(Partition)" 7 0 0 \
        B Browse A Add R Remove ) || exit 1; clear
    case $options in
    B)
        brow_mtp
        ;;
    A)
        mtp_name=$(dialog --stdout --title "ArchQ" --inputbox "Add player(partition)" 0 0) || exit 1; clear
        mtp_file="/etc/mpd.d/mtp_${mtp_name@u}.out"
echo "include_optional \"mpd.d/mtp_${mtp_name@u}.out\"" >>$config
# echo 'partition {'                      >$mtp_file
# echo '	name	"'${mtp_name@u}'"'    >>$mtp_file
# echo '}'                                >>$mtp_file
echo 'audio_output {'                   >$mtp_file
echo '	type	"fifo"'                 >>$mtp_file
echo '	name	"'${mtp_name@u}'"'      >>$mtp_file
echo '	path	"/var/lib/mpd/'${mtp_name@u}'/air"' >>$mtp_file
echo '	format	"44100:16:2"'           >>$mtp_file
echo '}'                                >>$mtp_file

    [[ -d /var/lib/mpd/${mtp_name@u} ]] || install -o mpd -g mpd -m 755 -d //var/lib/mpd/${mtp_name@u}
    ln -s "/etc/systemd/system/owntone@.service" "/etc/systemd/system/owntone@${mtp_name@u}"
    ot_conf=/etc/owntone-${mtp_name@u}.conf
    ports=$(cat /etc/owntone-*.conf | grep port | cut -d ' ' -f 3)
    max=3689
    for n in ${ports[@]}; do
        [[ $n > $max ]] && max=$n
    done
    cat >$ot_conf <<EOF
general {
	uid = "owntone"
	loglevel = fatal
	ipv6 = no
	cache_daap_threshold = 1000
	speaker_autoselect = no
	high_resolution_clock = yes
}

library {
EOF
echo '	port = '$((max+1))          >>$ot_conf
echo '	directories = { "/var/lib/mpd/'${mtp_name@u}'" }' >>$ot_conf
echo '	follow_symlinks = false'    >>$ot_conf
echo '}'                            >>$ot_conf

    brow_mtp
    systemctl enable --now avahi-daemon.socket owntone@${mtp_name@u}
        ;;
    R)
        MENU=''
        while read line; do
            MENU=${MENU}${line}' 　 '
        done <<< $(cat $config | grep mtp_ | cut -d '_' -f 3 | cut -d '.' -f1)
        options=$(dialog --stdout --title "ArchQ MPD" --menu "Remove player(partition)" 7 0 0 $MENU ) || exit 1; clear
        systemctl disable --now owntone@${options}
        sed -i '/mtp_'"$options"'/d' $config
        rm -f /etc/mpd.d/mtp_${options}.out /etc/owntone-${options}.conf /etc/systemd/system/owntone@Bedroom
        brow_mtp
        ;;
    esac

fi
## Httpd stream output on/off
if [[ $h1 == on ]]; then
    ht_conf='/etc/mpd.d/httpd.out'
    sed -i 's/^#.\?include_optional "mpd.d\/httpd.out"/include_optional "mpd.d\/httpd.out"/' $config
    http_flac=off; http_wave=off; http_lame=off
    declare http_$(cat $ht_conf | grep 'encoder' $2 | cut -d'"' -f2)=on
    MENU='flac 　 '$http_flac' wave 　 '$http_wave
    pacman -Q mpd-ffmpeg >/dev/null 2>&1 && MENU=${MENU}' mp3 　 '$http_lame
    encoder=$(dialog --stdout --title "ArchQ MPD" --radiolist "Http:8000 codec" 7 0 0 $MENU) || exit 1
    clear
    sed -i 's/name.*"/name\t"'"Stream.$encoder"'"/' $ht_conf
    [[ $encoder == 'mp3' ]] && encoder=lame
    sed -i 's/encoder.*"/encoder\t"'"$encoder"'"/' $ht_conf
else   
    sed -i 's/^include_optional "mpd.d\/httpd.out"/#include_optional "mpd.d\/httpd.out"/' $config
fi
## Dop on/off
[[ $d1 == on ]] && sed -i 's/^#.\?dop.*/\tdop\t"yes"/;s/dsd64:.* /dsd64:*=dop /;s/dsd128:.*"/dsd128:*=dop"/' $config \
                || sed -i 's/^[[:space:]]dop.*/#\tdop\t"yes"/;s/=dop//g' $config

### Buffer, bitDepth, Upsampling, & Music Directory 
mdir=$(grep 'music_directory' $config | cut -d'"' -f2 | cut -d'/' -f3-)
buffer=$(grep 'audio_buffer_size' $config | cut -d'"' -f2 | cut -d'/' -f3-)
pertime=$(grep 'period_time' $config | cut -d'"' -f2 | cut -d'/' -f3-)
bitdepth=$(grep -P '\tallowed_formats' $config | awk '{print $2}' | cut -d':' -f2)
sampling=$(grep 'upsampling_two_multiple' $config | cut -d'"' -f2)

options=$(dialog --stdout --title "ArchQ MPD" --ok-label "Ok" --form "Buffer & Music directory" 0 40 0 \
    "Audio Buffer >=128"        1 1 $buffer   1 25 40 0 \
    "Period Time(μs)"           2 1 $pertime  2 25 40 0 \
    "Bit Depth(16/24/32)"       3 1 $bitdepth 3 25 40 0 \
    "Upsampling Two Multiple"   4 1 $sampling 4 25 40 0 \
    "Music Dir          /mnt/"  5 1 "$mdir"   5 25 40 0 ) || exit 1; clear
    
beffer=$(echo $options | awk '//{print $1 }')
pertime=$(echo $options | awk '//{print $2 }')
buftime=$(($pertime * 6))
bitdepth=$(echo $options | awk '//{print $3 }')
sampling=$(echo $options | awk '//{print $4 }')
mdir=$(echo $echo $options | awk '//{print $5}' | sed 's"/"\\\/"g')

## Set ramdisk
# rd_GB=$(echo $options | awk '//{print $3 }')
# if [ $rd_GB = '0' ]; then
#     rm -f /var/lib/mpd/playlists/RAMDISK.m3u
# else
#     touch /tmp/RAMDISK.m3u
#     install -Dm 644 -o mpd -g mpd /tmp/RAMDISK.m3u -t /var/lib/mpd/playlists/
# fi
# if [ -f /usr/bin/mpd-rdcheck.sh ]; then
#     ramdisk=$(python -c "print(int($rd_GB*1048576))")
#     sed -i 's/rdsize=.*/rdsize='"$ramdisk"'/' /usr/bin/mpd-rdcheck.sh
# fi
sed -i 's/^#\?audio_buffer_size.*"/audio_buffer_size\t"'"$beffer"'"/' $config
sed -i 's/^#\?.* \?\tbuffer_time.*"/\tbuffer_time\t"'"$buftime"'"/;s/^#\?.* \?\tperiod_time.*"/\tperiod_time\t"'"$pertime"'"/' $config
sed -i 's/^#\?.allowed_formats .*"*:..:/\tallowed_formats "*:'"$bitdepth"':/' $config
sed -i 's/^#\?.upsampling_two_multiple.*"/\tupsampling_two_multiple\t"'"$sampling"'"/' $config
sed -i 's/^#\?music_directory.*"/music_directory\t"\/mnt\/'"$mdir"'"/' $config

### Blissify scan music directory as mpd
[[ -f /etc/blissify.conf ]] && sed -i 's/"mpd_base_path": ".*/"mpd_base_path": "'"$mdir"'"/' /etc/blissify.conf

### Restart MPD
systemctl restart mpd