#!/bin/sh
# 動画サイトの動画ファイルへの直接なリンクを表示するスクリプト
# 複数の画質があり、urlだけでは判別ができない場合に限りurlの下に詳細を >&2 で出力してます
# 日付は書いた日
# 最初だけ、手当たりしだい追加していくので見ない奴はメンテナンスされないので注意
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
# 2013/03/15 youtube.com{{{
# 正直、youtube-dlを使ったほうが良い(よくメンテナンスされているので)
# 複数のurlが表示されるので画質は |grep 'itag=数値' で選ぶ
# その数値を調べるには |grep -o 'itag=[^&]*'で色々と表示される
# 複数表示される場合があるので必ず|head -1もつけること
    'www.youtube.com')
# 動画を見るページか判定{{{
        echo "${1#*//*/}"|grep -E '^watch\?(.*&)?v=[0-9a-zA-Z-]+($|&).*$' >/dev/null 2>&1
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
# 2012/12/18 xvideos.com{{{
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
# 2013/01/09 tokyo-porn-tube.com (2013/03/16 tokyo-tube){{{
    'www.tokyo-porn-tube.com'|'www.tokyo-tube.com')
# 動画を見るページか判定{{{
        echo "${1#*//*/}"|grep -E '^video/[0-9]+/.*$' >/dev/null 2>&1
        if [ "${?}" == '1' ];then
            echo "unsupport url: ${1}" >&2
            exit 1
        fi
# }}}動画を見るページか判定
        web_fetch "${1%%/video/*}/media/player/config.php?vkey=`echo "${1}"|grep -E -o '/video/[0-9]+'|sed -e 's|^/video/||'`"|grep -o '<src>.*\.flv</src>'|sed -e 's|<src>||' -e 's|</src>||'
        ;;
# }}}tokyo-porn-tube.com
# 2013/03/13 asg.to{{{
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
# 2013/03/16 fc2.com{{{
    'video.fc2.com')
# seed値はswfdumpで抽出
# 落とす時はginfo.phpにアクセスした時のuseragentと同じでないと弾かれるので
# web_fetch関数に使ったダウンローダと動画プレイヤーのuseragentを合わせておくように
# 動画を見るページか判定{{{
        echo "${1#*//*/}"|grep -E '^(../)?(a/)?content/[0-9]+[0-9a-zA-Z]+(&|$).*$' >/dev/null 2>&1
        if [ "${?}" == '1' ];then
            echo "unsupport url: ${1}" >&2
            exit 1
        fi
# }}}動画を見るページか判定
        fc2_seed='gGddgPfeaf_gzyr'
        fc2_part="`web_fetch "${1}"|\
        grep -E -o '<param name="FlashVars"[^>]*'|grep -E -o 'value="[^"]*'|sed -e 's/value="//' -e 's/\&/\n/g'`"
        fc2_i="`echo "${fc2_part}"|grep '^i='|sed 's/^i=//'`"
        fc2_mimi="`printf "${fc2_i}_${fc2_seed}"|md5sum|grep -E -o '^[^ ]*'`"
        web_fetch "http://video.fc2.com/ginfo.php?mimi=${fc2_mimi}&v=${fc2_i}&upid=${fc2_i}"|sed -e 's/^filepath=//'|grep -E -o '^.*&mid=[^&]*'|sed -e 's/\&/?/g'
        ;;
# }}}fc2.com
# 2013/03/16 youporn.com{{{
    'www.youporn.com')
# 複数の画質があるので|head -1 などをして1つにしてから動画プレイヤーに渡してください
# 動画を見るページか判定{{{
        echo "${1#*//*/}"|grep -E '^watch/[0-9]+/.*$' >/dev/null 2>&1
        if [ "${?}" == '1' ];then
            echo "unsupport url: ${1}" >&2
            exit 1
        fi
# }}}動画を見るページか判定
        web_fetch "${1}"|\
        sed -ne '/<ul class="downloadList">/,/<\/ul>/p'|\
        grep -E -o '<a href="[^"]*'|\
        sed -e 's/<a href="//g' -e 's/\&amp;/\&/g'
        ;;
# }}}youporn.com
# 2013/03/16 himado.in{{{
    'himado.in')
# urlの下にセレクトメニューに書いてある文字列が表示されます
# 既にセレクト済みのurlを渡すと表示されるurlは1つだけでメニューの文字列は表示されません
# 複数表示された場合は直接urlをコピペするか
# 2>&1|grep -B 1 'セレクトメニューに書いてある文字列'|head -1
# こんな感じのコマンドを後ろにつけて実行すればいいです
# 既にセレクト済みか判定{{{
        echo "${1#*//*/}"|grep -E '^\?id=[0-9]+&(sid|def)=[0-9]+$' >/dev/null 2>&1
        if [ "${?}" == '0' ];then
            web_fetch "${1}"|\
            grep -E -o 'movie_url = "http[^"]*'|\
            sed -s 's/^movie_url.*"//'|\
            nkf --url-input
# }}}既にセレクト済みか判定
        else
            # 動画を見るページか判定{{{
            echo "${1#*//*/}"|grep -E '^[0-9]+$' >/dev/null 2>&1
            if [ "${?}" == '1' ];then
                echo "unsupport url: ${1}" >&2
                exit 1
            # }}}動画を見るページか判定
            else
                IFS=$'\n'
                for himado_tmp in `web_fetch "${1}"|grep -E -o '<select id=select_othersource.*</select>'|grep -E -o '<option value="[^<]*'|sed -e 's/^<option value="//g'`;do
                    web_fetch "http://himado.in/${himado_tmp%%\"*}"|\
                    grep -E -o 'movie_url = "http[^"]*'|\
                    sed -s 's/^movie_url.*"//'|\
                    nkf --url-input
                    echo -e "${himado_tmp#*>}\n" >&2
                done
            fi
        fi
        ;;
# }}}himado.in
# 2013/03/16 momovideo.net{{{
# urlの下にセレクトメニューに書いてある文字列が表示されます
    'momovideo.net')
# 動画を見るページか判定{{{
        echo "${1#*//*/}"|grep -E '^\?watchId=[0-9]+$' >/dev/null 2>&1
        if [ "${?}" == '1' ];then
            echo "unsupport url: ${1}" >&2
            exit 1
        fi
# }}}動画を見るページか判定
        momovideo_source="`web_fetch "${1}"`"
        momovideo_default="`echo "${momovideo_source}"|\
        grep -E -o "mediaUrl=http[^']*"|\
        sed -e 's/^mediaUrl=//'`"
        momovideo_sub="`echo "${momovideo_source}"|\
        grep -E '<select name="media_url".*</select>'|\
        grep -E -o '<option value="[^<]*'|\
        sed -e 's/^<option value="//g'`"
        IFS=$'\n'
        for momovideo_tmp in `echo "${momovideo_default}${momovideo_sub}"`;do
            echo "${momovideo_tmp%%\"*}"
            echo -e "${momovideo_tmp#*>}\n" >&2
        done
        ;;
# }}}momovideo.net
    *)
        echo "unknown site: ${1}"
esac
# vim:set fdm=marker:
