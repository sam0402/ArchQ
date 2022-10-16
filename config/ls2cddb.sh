#!/bin/bash
format='m4a'
cdpath='/media/Music/BR-Rip/'
#cdpath='/media/Music/Hi-Res/'
dropchar=2

cddbfile=$(ls abcde.*/cddbread.0)
sed -i '/DTITLE/,$d' $cddbfile

ARTIST=$(echo $1 | awk -F '(' '{print $2}'|sed 's/).*//;s/^ //')
COMPOSER=$(echo $1 | awk -F '(' '{print $1}' | awk -F ' - ' '{print $1}'| sed 's/ $//')
DTITLE=$(echo $1 | awk -F '(' '{print $1}' | awk -F ' - ' '{print $2}'| sed 's/ $//')

ALBUM="$COMPOSER: $DTITLE"
[ -z "$DTITLE" ] && ALBUM=$COMPOSER

echo "DTITLE=$ARTIST / $ALBUM" >>$cddbfile
echo "COMPOSER=$COMPOSER" >>$cddbfile
echo "DYEAR=" >>$cddbfile
echo "DGENRE=" >>$cddbfile

n=-1
while read line; do
    line=${line:$dropchar-0}
    ((n += 1 ))
    [[ $(echo $line | grep -E ".m4a|.flac") ]] && echo "TTITLE${n}="$(echo ${line} | sed 's/.m4a//;s/.flac//') >>$cddbfile
done <<< $(ls "$cdpath""$1" | grep -E ".m4a|.flac")
echo "EXTD=" >>$cddbfile
for i in $(seq 0 $n); do
    echo "EXTT$i=" >>$cddbfile
done
echo "PLAYORDER=" >>$cddbfile
