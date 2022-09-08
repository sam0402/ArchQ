#!/bin/bash
# file format included the wav
format='flac'
cdpath='/mnt/Music/'
dropchar=2

cddbfile=$(ls abcde.*/cddbread.0)
sed -i '/DTITLE/,$d' $cddbfile
echo "DTITLE=$(echo $1 | sed 's/ - / \/ /')" >>$cddbfile
echo "DYEAR=" >>$cddbfile
echo "DGENRE=" >>$cddbfile
n=-1
while read line; do
    line=${line:$dropchar-0}
    ((n += 1 ))
    [[ $(echo $line | grep -E ".${format}|.wav") ]] && echo "TTITLE${n}="$(echo ${line} | sed 's/.'"${format}"'//;s/.wav//;s/.flac//') >>$cddbfile
done <<< $(ls "$cdpath""$1" | grep $format)
echo "EXTD=" >>$cddbfile
for i in $(seq 0 $n); do
    echo "EXTT$i=" >>$cddbfile
done
echo "PLAYORDER=" >>$cddbfile
