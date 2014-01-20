#!/bin/sh
# zipの中にあるファイルを片っ端からmplayerに渡すプログラム

if [ -f "$1" ];then
    pipe=`mktemp -u`
    trap "rm \"${pipe}\";exit 1" 1 2 3 9 15
    trap "rm \"${pipe}\"" 0

    mkfifo "${pipe}"||{ echo 'error: mkfifo';exit 1; }
    IFS=$'\n'
    for zipInFile in `zipinfo -1 "${1}"|sed -e 's/\[/\\\\\[/g' -e 's/\]/\\\\\]/g'` ;do
        echo " --- staring: ${zipInFile}"
        unzip -p "${1}" "${zipInFile}" > "${pipe}" &
        mplayer "${pipe}"
    done
else
    echo "not found: $1"
    exit 1
fi
