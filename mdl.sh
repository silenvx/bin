#!/bin/sh
# 動画サイトの動画ファイルへの直接なリンクを表示するスクリプト
# 複数の画質があり、urlだけでは判別ができない場合に限りurlの下に詳細を >&2 で出力してます
# 日付は書いた日
# サイトは手当たりしだい追加していくので見ない奴はメンテナンスしないので注意
# md5sum wget grep sed printf echo cut nkf stringsなどで実装されてます
web_fetch(){
    wget --quiet -O - "${@}"
}

mdl_support(){
    echo "${1#*//*/}"|grep -E "${2}" >/dev/null 2>&1
    if [ "${?}" == '1' ];then
        echo "unsupport url: ${1}" >&2
        exit 1
    fi
}

nicovideo_login(){
    printf 'nicovideo.jp mail       > ' >&2
    read nicovideo_mail
    stty -echo
    printf 'nicovideo.jp password   > ' >&2
    read nicovideo_password
    stty echo
    echo >&2
    wget --quiet --secure-protocol=SSLv3 \
    --keep-session-cookies \
    --save-cookies="${3}" \
    --post-data "next_url=${1#*nicovideo.jp}&mail=${nicovideo_mail}&password=${nicovideo_password}" \
    "https://secure.nicovideo.jp/secure/login?site=${2}" \
    -O -
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
        mdl_support "${1}" '^watch\?(.*&)?v=[0-9a-zA-Z-_]+($|&).*$'
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
        mdl_support "${1}" '^video[0-9]+/.*'
        web_fetch "${1}"|grep -o 'flv_url=[^&]*'|sed -e 's/^flv_url=//'|nkf --url-input
        ;;
# }}}xvideos
# 2013/01/09 tokyo-porn-tube.com (2013/03/16 tokyo-tube){{{
    'www.tokyo-porn-tube.com'|'www.tokyo-tube.com')
        mdl_support "${1}" '^video/[0-9]+/.*$'
        web_fetch "${1%%/video/*}/media/player/config.php?vkey=`echo "${1}"|grep -E -o '/video/[0-9]+'|sed -e 's|^/video/||'`"|grep -o '<src>.*\.flv</src>'|sed -e 's|<src>||' -e 's|</src>||'
        ;;
# }}}tokyo-porn-tube.com
# 2013/03/13 asg.to{{{
# UraAgesage.site.jsを参考に書いた
    'asg.to')
        mdl_support "${1}" '^contentsPage\.html\?mcd=[0-9a-zA-Z]+$'
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
        mdl_support "${1}" '^(../)?(a/)?content/[0-9]+[0-9a-zA-Z]+(&|$).*$'
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
        mdl_support "${1}" '^watch/[0-9]+/.*$'
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
            mdl_support "${1}" '^[0-9]+$'
            IFS=$'\n'
            for himado_tmp in `web_fetch "${1}"|grep -E -o '<select id=select_othersource.*</select>'|grep -E -o '<option value="[^<]*'|sed -e 's/^<option value="//g'`;do
                web_fetch "http://himado.in/${himado_tmp%%\"*}"|\
                grep -E -o 'movie_url = "http[^"]*'|\
                sed -s 's/^movie_url.*"//'|\
                nkf --url-input
                echo -e "${himado_tmp#*>}\n" >&2
            done
        fi
        ;;
# }}}himado.in
# 2013/03/16 momovideo.net{{{
# urlの下にセレクトメニューに書いてある文字列が表示されます
    'momovideo.net')
        mdl_support "${1}" '^\?watchId=[0-9]+$'
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
# 2013/03/16 dailymotion.com{{{
# 画質が複数あります
    'www.dailymotion.com')
        mdl_support "${1}" '^video/[0-9a-zA-Z_-]+$'
        web_fetch "${1}"|\
        grep -E -o 'sequence":"[^"]*'|\
        nkf --url-input|\
        grep -E -o '"(ld|sd|hq|hd720)URL":"[^"]*'|\
        sed -e 's/^"[^"]*URL":"//g' -e 's|\\/|/|g'
        ;;
# }}}dailymotion.com
# 2013/03/17 ted.com{{{
# rtmpのurlに書かれている1500kなどはビットレートです
# たぶん、これによって画質も異なる
# 全部を確かめたわけではないけども
#   1500k   1280x720
#    950k    854x480
#    600k    640x360
#    450k    512x288
#    320k    512x288
#    180k    512x288
#     64k    398x224
# となっていると思う。出力する処理を書くのは面倒だったので書いていません
    'www.ted.com')
        mdl_support "${1}" '^talks/[0-9a-zA-Z_]+\.html$'
        ted_source="`web_fetch "${1}"`"
# httpのurl
        echo "${ted_source}"|\
        grep -E -o '<a id="no-flash-video-download" href="[^"]*'|\
        sed -e 's/^<a id="no-flash-video-download" href="//'
# rtmpのurl
        ted_flashvars="`echo "${ted_source}"|\
        grep -E -o '"flashVars":{[^}]*'|\
        grep -E -o '"playlist":"[^"]*'|\
        nkf --url-input|\
        sed -e 's|\\\\/|/|g'`"
        ted_host="`echo "${ted_flashvars}"|\
        grep -E -o '"streamer":"[^"]*'|sed -e 's/^"streamer":"//'`"
        for ted_path in `echo "${ted_flashvars}"|grep -E -o '"mp4:[^"]*'|sed -e 's/^"mp4://'`;do
            echo "${ted_host}/${ted_path}"
        done
        ;;
# }}}ted.com
# 2013/03/17 ustream.tv{{{
    'www.ustream.tv')
# リダイレクト先が動画がへのパス
# /recorded/[0-9]+${{{
        echo "${1#*//*/}"|grep -E '^recorded/[0-9]+$' >/dev/null 2>&1
        if [ "${?}" == '0' ];then
            echo "http://tcdn.ustream.tv/video`echo "${1}"|grep -E -o '/[0-9]+$'`"
# }}}/recorded/[0-9]+$
# 同じurlがあるのは仕様です
# rtmpdumpに渡す形式で出力されます
# mplayerで再生するならば
# eval rtmpdump -v -q -o - "`mdl.sh 'ustreamのurl'|head -1`" |mplayer -
# こんな感じで使用できます
# たまに再生できない動画があるのは仕様です
# /channel/.+${{{
        else
            mdl_support "${1}" '^channel/.+$'
            ustream_cid="`web_fetch "${1}"|\
            grep -E -o 'cid=[0-9]+'|\
            head -1|\
            sed -e 's/^cid=//'`"
            ustream_amf="`web_fetch "http://cdngw.ustream.tv/Viewer/getStream/1/${ustream_cid}.amf"|\
            strings`"
# cdn{{{
            ustream_rtmp="`echo "${ustream_amf}"|\
            grep -E '^(akamai|stream_live|.+rtmp:\/\/.*(fplive.net|edgefcs.net)/).+$'`"
            ustream_flag='0'
            IFS=$'\n'
            for ustream_tmp in ${ustream_rtmp};do
                echo "${ustream_tmp}"|\
                grep -E '^.*rtmp:\/\/.+$' >/dev/null 2>&1
                if [ "${?}" == 0 ];then
                    ustream_url="${ustream_tmp#*rtmp:}"
                else
                    ustream_path="${ustream_tmp}"
                fi
                if [ "${ustream_flag}" == '1' ];then
                    echo "-s 'http://www.ustream.tv/flash/viewer.swf' -r 'rtmp:${ustream_url}/${ustream_path}'"
                    ustream_flag='0'
                    continue
                fi
                ustream_flag='1'
            done
# }}}cdn
# FIXME:fmsを使う放送が見当たらなかったので途中
# fms{{{
            ustream_rtmp="`echo "${ustream_amf}"|\
            grep -E -o 'rtmp://.+/ustreamVideo/[0-9]+'`"
            if [ -n "${ustream_rtmp}" ];then
                echo "-s 'http://www.ustream.tv/flash/viewer.swf' -r '${ustream_rtmp}' -a '${ustream_rtmp##+/}' -y 'streams/live'"
            fi
# }}}fms
# }}}/channel/.+$
        fi
        ;;
# }}}ustream.tv
# 2013/03/18 *.nicovideo.jp{{{
    'live.nicovideo.jp'|'www.nicovideo.jp')
# ログインが必要なサービスなので最初にidとpwを要求します

# 動画のダウンロードにcookieが必要なので例えばmplayerで再生するなら
# mplayer -cookies -cookies-file ${nicovideo_cookies}" "`mdl.sh 'ニコニコ動画のurl'`"
# だいたいこんな感じで再生が可能です
# そういうわけで標準出力をする時はcookieの分も出力しています。なので
# eval mplayer "`mdl.sh ニコニコ動画のurl`"
# 再生する時はこんな感じになります
# www.nicovideo.jp{{{
        nicovideo_cookies='/tmp/mdl_cookies_nicovideo.txt'
        echo "${1#*//}"|grep -E '^www\..+' >/dev/null 2>&1
        if [ "${?}" == '0' ];then
            mdl_support "${1}" '^watch/.+$'
            nicovideo_login "${1}" 'niconico' "${nicovideo_cookies}"> /dev/null
            nicovideo_url="`wget --quiet --load-cookies="${nicovideo_cookies}" -O - "http://flapi.nicovideo.jp/api/getflv?v=${1#*/watch/}"|\
            grep -E -o 'url=[^&]+'|\
            sed -e 's/^url=//'|\
            nkf --url-input`"
            echo "-cookies -cookies-file '${nicovideo_cookies}' '${nicovideo_url}'"
# }}}www.nicovideo.jp
# rtmpdumpに渡す形式で出力されます
# eval rtmpdump "`mdl.sh 'ニコニコ生放送のURL'|head -1`" rtmpdumpの使いたいパラメータ
# といった感じで使用できます
# live.nicovideo.jp{{{
        else
            mdl_support "${1}" '^watch/.+$'
            nicovideo_source="`nicovideo_login "${1}" 'nicolive' ''|\
            nkf --url-input|\
            grep 'getplayerstatus'`"
            nicovideo_provider="`echo "${nicovideo_source}"|\
            grep -E -o '<provider_type>[^<]+'|sed -e 's/<provider_type>//'`"
            case "${nicovideo_provider}" in
# 何もいじっていないrtmpdumpでも動作可能
# urlにはpremiumやmobileやdefault用など複数の種類があるので種類はurlの下に >&2 で表示しています
# そういうわけでその情報を利用して選択するならば
# mdl.sh 'ニコニコ生放送のURL' 2>&1|grep -B 1 '^premium'|head -1
# このような感じで絞れますが簡易的なログイン画面もgrepに持っていかれるので注意
# 公式生放送{{{
            'official')
                nicovideo_list="`echo "${nicovideo_source}"|\
                grep -E -o '<contents id="main"[^<]+'|sed -e 's/^<contents[^>]+>//'|\
                sed -e 's/^.*>case://' -e 's/,/\n/g'|\
                nkf --url-input|\
                sed -e 's|,|/|g'`"
                for nicovideo_tmp in ${nicovideo_list};do
                    nicovideo_url="`echo "${nicovideo_tmp}"|\
                    grep -E -o 'rtmp://.+$'`"
                    nicovideo_url="${nicovideo_url}?$(echo "${nicovideo_source}"|grep -E -o "<stream name=\"${nicovideo_url##*/}\">[^<]+"|sed -E -e 's/^<[^>]+>//' -e 's/\&amp\;/\&/g')"
                    echo "-r '${nicovideo_url}' -C 'S:${nicovideo_url##*/}'"
                    echo "${nicovideo_tmp}"|\
                    grep -E -o '^[^:]+:[^:]+:' >&2
                    echo >&2
                done
                ;;
# }}}公式生放送
# -Nオプションが使える(ニコニコ生放送に対応した)rtmpdumpでないと使用不可
# linux版は
# https://github.com/taonico/rtmpdump-nico-live
# これを参考にpatchを書けば動きます
# ユーザーもしくはチャンネル{{{
            'community'|'channel')
                nicovideo_n="`echo "${nicovideo_source}"|\
                grep -E -o '<contents id="main"[^<]+'|\
                sed -E -e 's/.+>rtmp://'`"
                nicovideo_url="`echo "${nicovideo_source}"|\
                grep -E -o '<url[^<]+'|\
                sed -E -e 's/.+>//'`"
                nicovideo_ticket="`echo "${nicovideo_source}"|\
                grep -E -o '<ticket[^<]+'|\
                sed -E -e 's/.+>//'`"
                echo "-r '${nicovideo_url}' -C 'S:${nicovideo_ticket}' -N '${nicovideo_n}'"
                ;;
# }}}ユーザーもしくはチャンネル
            *)
                echo "unsupport provider type:${nicovideo_provider} url:${1}" >&2
                exit 1
                ;;
            esac
# }}}live.nicovideo.jp
        fi
        ;;
# }}}*.nicovideo.jp
    *)
        echo "unknown site: ${1}"
esac
# vim:set fdm=marker:
