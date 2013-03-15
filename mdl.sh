#!/bin/sh
# 動画サイトの動画ファイルへの直接なリンクを表示するスクリプト
web_fetch(){
    wget --quiet -O - "${@}"
}

# urlか判定{{{
echo "${1}"|grep -e '^http://' -e '^https://' >/dev/null 2>&1
if [ "${?}" == '1' ];then
    echo "not url: ${1}" >&2
    exit 1
fi
# }}}urlか判定

case `echo "${1}"|cut -d '/' -f 3` in
# youtube.com 2013/03/15 {{{
# 正直、youtube-dlを使ったほうが良い(よくメンテナンスされているので)
# 複数のurlが表示されるので画質は |grep 'itag=数値' で選ぶ
# その数値を調べるには |grep -o 'itag=[^&]*'で色々と表示される
# 複数表示される場合があるので必ず|head -1もつけること
    'www.youtube.com')
# 動画を見るページか判定{{{
        echo "${1#*//*/}"|grep -E '^watch\?v=[0-9a-zA-Z]+$' >/dev/null 2>&1
        if [ "${?}" == '1' ];then
            echo "unsupport url: ${1}" >&2
            exit 1
        fi

# }}}動画を見るページか判定
        for youtube_tmp in `web_fetch "${1}"|grep -E -o '"url_encoded_fmt_stream_map": "[^"]*'|sed -e 's/^"url_encoded_fmt_stream_map": "//' -e 's/,/\n/g' |nkf --url-input`;do
            youtube_part="`echo "${youtube_tmp}"|\
            sed -e 's/\\\\u0026/\n/g'`"
            youtube_url="`echo "${youtube_part}"|grep '^url='`"
            youtube_fallback_host="`echo "${youtube_part}"|grep '^fallback_host='`"
            youtube_quality="`echo "${youtube_part}"|grep '^quality='`"
#            youtube_itag="`echo "${youtube_part}"|grep '^itag='`"
            youtube_sig="`echo "${youtube_part}"|grep '^sig='`"
            youtube_type="`echo "${youtube_part}"|grep '^type='`"

            echo "${youtube_url#url=}&${youtube_fallback_host}&${youtube_quality}&${youtube_sig/sig=/signature=}&${youtube_type}"
        done
        ;;
# }}}youtube.com
# xvideos.com 2012/12/18{{{
    'www.xvideos.com'|'www.xvideos.jp')
# 動画を見るページか判定{{{
        echo "${1#*//*/}"|grep -E '^video[0-9]+/.*' >/dev/null 2>&1
        if [ "${?}" == '1' ];then
            echo "unsupport url: ${1}" >&2
            exit 1
        fi
# }}}動画を見るページか判定
        web_fetch "${1}"|grep -o 'flv_url=[^&]*'|sed -e 's/^flv_url=//'|nkf --url-input
        ;;
# }}}xvideos
# tokyo-porn-tube.com 2013/01/09{{{
    'www.tokyo-porn-tube.com')
# 動画を見るページか判定{{{
        echo "${1#*//*/}"|grep -E '^video/[0-9]+/.*$' >/dev/null 2>&1
        if [ "${?}" == '1' ];then
            echo "unsupport url: ${1}" >&2
            exit 1
        fi
# }}}動画を見るページか判定
        web_fetch "http://www.tokyo-porn-tube.com/media/player/config.php?vkey=`echo "${1}"|grep -o '/video/[0-9]*'|grep -o '[0-9]*'`"|grep -o '<src>.*\.flv</src>'|sed -e 's|<src>||' -e 's|</src>||'
        ;;
# }}}tokyo-porn-tube.com
# asg.to 2013/03/13{{{
# UraAgesage.site.jsを参考に書いた
    'asg.to')
# 動画を見るページか判定{{{
        echo "${1#*//*/}"|grep -E '^contentsPage\.html\?mcd=[0-9a-zA-Z]+$' >/dev/null 2>&1
        if [ "${?}" == '1' ];then
            echo "unsupport url: ${1}" >&2
            exit 1
        fi
# }}}動画を見るページか判定
        asg_seed='---===XERrr3nmsdf8874nca===---'
        asg_mcd="${1#*mcd=}"
        asg_pt="`web_fetch "${1}"|grep -E -o 'urauifla\("[^"]*&pt[^"]*'|grep -E -o '&pt[^&]*'|sed -e 's/&pt=//'`"
        asg_st="`printf -- "${asg_seed}${asg_mcd}$(printf "${asg_pt}"|cut -c1-8)"|md5sum|grep -E -o '^[^ ]*'`"
        web_fetch "http://asg.to/contentsPage.xml?mcd=${asg_mcd}&pt=${asg_pt}&st=${asg_st}"|grep '<movieurl>'|grep -E -o 'http://[^<]*'
        ;;
# }}}asg.to
    *)
        echo "unknown site: ${1}"
esac
# vim:set fdm=marker:
