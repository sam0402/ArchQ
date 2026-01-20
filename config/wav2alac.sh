#!/bin/bash
## Exective the script in music directory (/mnt/music)
# The format of files to conver
EXTNAME='wav'
COVER='cover.jpg'
TDIR='/mnt/m4a'

function ENCODE() {
    # Decode to WAV
    schedtool -a $(($(getconf _NPROCESSORS_ONLN)-1)) -e ffmpeg -nostdin -i "$1" -c:a alac -fflags +bitexact "$2" >/dev/null 2>&1
    atomicparsley "$2" --overWrite --artwork REMOVE_ALL --artwork cover.jpg
}

for ALPHA in {A..Z}; do
    while read sdir; do
        m4adir="$TDIR/$sdir"
        mkdir -p "$m4adir"
        cd "$sdir"
        echo "$sdir"
        convert 'cover.jpg' -resize 600x600 "$m4adir/cover.jpg"
        while read sf; do
            tf=${sf%.$EXTNAME}
            ENCODE "$sf" "$m4adir/$tf.m4a"
        done <<< $(ls *.$EXTNAME)
        cd - >/dev/null
    done <<< $(find -type d | grep "^./$ALPHA")
done