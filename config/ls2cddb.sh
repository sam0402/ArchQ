#!/bin/bash
format='m4a'
cdpath='/media/Music/BR-Rip/'

cddbfile=$(ls abcde.*/cddbread.0)
sed -i '/DTITLE/,$d' $cddbfile
echo "DTITLE=$(echo $1 | awk -F '/' '{print $5}' | sed 's/ - /\//')" >>$cddbfile
echo "DYEAR=" >>$cddbfile
echo "DGENRE=" >>$cddbfile
n=-1
while read line; do
    ((n += 1 ))
    [[ $(echo $line | grep '.m4a') ]] && echo "TTITLE${n}="$(echo ${line} | sed 's/.m4a//') >>$cddbfile
done <<< $(ls "$cdpath""$1" | grep $format | cut -d ' ' -f2-)
echo "EXTD=" >>$cddbfile
for i in $(seq 0 $n); do
    echo "EXTT$i=" >>$cddbfile
done
echo "PLAYORDER=" >>$cddbfile
