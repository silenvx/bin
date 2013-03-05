#!/bin/sh
if [ "${#}" != '1' ];then
    echo "引数にflacファイルを指定してください"
    exit 1
fi
cue='CDImage.cue'

metaflac --show-tag="CUESHEET" "${1}"|sed -e '1s/^CUESHEET=//' > "${cue}"
shnsplit "${1}" -f "${cue}" -o 'cust ext=mp3 lame --add-id3v2 -b 320 --quiet - %f' -t '%n. %t'

information=`cat "${cue}"|sed -n "1,/FILE/p"`
album=`echo "${information}"|grep '^TITLE'|sed -e 's/^TITLE[^"]*"//' -e 's/"$//'`
year=`echo "${information}"|grep '^MESSAGE'|grep -o '[0-9][0-9][0-9][0-9]'`

track_total=`cat "${cue}"|grep '^TRACK'|wc -l`

IFS=$'\n'
for i in `find . -type f -name '*.mp3'`;do
    filename=${i##*/}
    track=${filename%%.*}
    information=`cat "${cue}"|sed -n "/TRACK ${track}/,/INDEX/p"`
    title=`echo "${information}"|grep '^TITLE'|sed -e 's/^TITLE[^"]*"//' -e 's/"$//'`
    artist=`echo "${information}"|grep '^PERFORMER'|sed -e 's/^PERFORMER[^"]*"//' -e 's/"$//'`

    eyeD3 --to-v2.3 \
    --set-encoding=utf16-LE \
    --artist="${artist}" \
    --album="${album}" \
    --title="${title}" \
    --track="${track}" \
    --track-total="${track_total}" \
    --year="${year}" \
    "${i}"
done
