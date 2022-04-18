#!/bin/bash
format='wav'
cdpath='/mnt/Music/'

cddbfile=$(ls abcde.*/cddbread.0)
sed -i '/DTITLE/,$d' $cddbfile
echo "DTITLE=$(echo $1 | sed 's/ - / \/ /')" >>$cddbfile
echo "DYEAR=" >>$cddbfile
echo "DGENRE=" >>$cddbfile
n=-1
while read line; do
    ((n += 1 ))
    [[ $(echo $line | grep ".${format}") ]] && echo "TTITLE${n}="$(echo ${line} | sed 's/.'"${format}"'//;s/：/:/') >>$cddbfile
done <<< $(ls "$cdpath""$1" | grep $format | cut -d ' ' -f2-)
echo "EXTD=" >>$cddbfile
for i in $(seq 0 $n); do
    echo "EXTT$i=" >>$cddbfile
done
echo "PLAYORDER=" >>$cddbfile
