#!/bin/sh
# nico_live.sh rtmp://プロトコル lv[0-9]の放送番号を指定して
# マイクの音声が流せるだけ
# 静止画も対応したいがエラーが出て今はよくわからないので保留中
# エラー処理{{{
if [ $# -ne 2 ];then
    echo "error: 引数の数が2個ではありません。以下のような正規表現になるように実行してください" >&2
    echo "sample: $0 rtmp://.+ lv[0-9]+" >&2
    exit 1
fi

if [ -z "`echo $1|grep -E '^rtmp://.+'`" ];then
    echo "error: \$1がrtmpプロトコルではないです" >&2
    exit 1
fi

if [ -z "`echo $2|grep -E '^lv[0-9]+$'`" ];then
    echo "error: \$2がニコ生の放送番号っぽくないです" >&2
    exit 1
fi
# }}}エラー処理
video_image="`dirname $0`/logo_soundonly.png"

ffmpeg -r 1 -y \
    -f alsa -i hw:0 -ar 44100 -strict 2 \
    -f flv "$1/$2 flashver=FMLE/3.0\20(compatible;\20FMSc/1.0) swfUrl=$2"
#    -f image2 -loop 1 -t 00:00:05 -i "${video_image}" -vcodec libx264 -s 512x384 -b:v 100k \
# vim:set foldmethod=marker:
