#!/bin/sh
# 動画サイトの動画ファイルへの直接なリンクを表示するスクリプト
# 複数の画質があり、urlだけでは判別ができない場合に限りurlの下に詳細を >&2 で出力してます
# 日付は書いた日
# サイトは手当たりしだい追加していくので見ない奴はメンテナンスしないので注意
# md5sum wget grep sed printf echo cut nkf stringsなどで実装されてます
# 関数群{{{
# ウェブページを取得する関数{{{
web_fetch(){
    wget --quiet -O - "${@}"
}
# }}}ウェブページを取得する関数
# サポートしているURLか判定する関数{{{
mdl_support(){
    echo "${1#*//*/}"|grep -E "${2}" >/dev/null 2>&1
    if [ "${?}" == '1' ];then
        echo "unsupport url: ${1}" >&2
        exit 1
    fi
}
# }}}サポートしているURLか判定する関数
# ニコニコにログインする関数{{{
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
# }}}ニコニコにログインする関数
# get_*{{{
# 2013/03/15 youtube.com{{{
get_youtube(){
# 正直、youtube-dlを使ったほうが良い(よくメンテナンスされているので)
# 複数のurlが表示されるので画質は |grep 'itag=数値' で選ぶ
# その数値を調べるには |grep -o 'itag=[^&]*'で色々と表示される
# 複数表示される場合があるので必ず|head -1もつけること
    mdl_support "${1}" '^watch\?(.*&)?v=[0-9a-zA-Z-_]+($|&).*$'
    for youtube_tmp in `web_fetch "${1}"|grep -E -o '"url_encoded_fmt_stream_map": "[^"]*'|sed -e 's/^"url_encoded_fmt_stream_map": "//' -e 's/,/\n/g' |nkf --url-input`;do
        local youtube_part="`echo "${youtube_tmp}"|\
        sed -e 's/\\\\u0026/\n/g'`"
        local youtube_url="`echo "${youtube_part}"|grep '^url='`"
        local youtube_fallback_host="`echo "${youtube_part}"|grep '^fallback_host='`"
        local youtube_quality="`echo "${youtube_part}"|grep '^quality='`"
#        local youtube_itag="`echo "${youtube_part}"|grep '^itag='`"
        local youtube_sig="`echo "${youtube_part}"|grep '^sig='`"
        local youtube_type="`echo "${youtube_part}"|grep '^type='`"

        echo "${youtube_url#url=}&${youtube_fallback_host}&${youtube_quality}&${youtube_sig/sig=/signature=}&${youtube_type}"
    done
}
# }}}youtube.com
# 2012/12/18 xvideos.com{{{
get_xvideos(){
    mdl_support "${1}" '^video[0-9]+/.*'
    web_fetch "${1}"|grep -o 'flv_url=[^&]*'|sed -e 's/^flv_url=//'|nkf --url-input
}
# }}}xvideos.com
# 2013/01/09 tokyo-porn-tube.com (2013/03/16 tokyo-tube){{{
get_tokyotube(){
    mdl_support "${1}" '^video/[0-9]+/.*$'
    web_fetch "${1%%/video/*}/media/player/config.php?vkey=`echo "${1}"|grep -E -o '/video/[0-9]+'|sed -e 's|^/video/||'`"|grep -o '<src>.*\.flv</src>'|sed -e 's|<src>||' -e 's|</src>||'
}
# }}}tokyo-porn-tube.com
# 2013/03/13 asg.to{{{
# UraAgesage.site.jsを参考に書いた
get_asg(){
    mdl_support "${1}" '^contentsPage\.html\?mcd=[0-9a-zA-Z]+$'
    local asg_seed='---===XERrr3nmsdf8874nca===---'
    local asg_mcd="${1#*mcd=}"
    local asg_pt="`web_fetch "${1}"|grep -E -o 'urauifla\("[^"]*&pt[^"]*'|grep -E -o '&pt[^&]*'|sed -e 's/&pt=//'`"
    local asg_st="`printf -- "${asg_seed}${asg_mcd}$(printf "${asg_pt}"|cut -c1-8)"|md5sum|grep -E -o '^[^ ]*'`"
    web_fetch "http://asg.to/contentsPage.xml?mcd=${asg_mcd}&pt=${asg_pt}&st=${asg_st}"|grep '<movieurl>'|grep -E -o 'http://[^<]*'
}
# }}}asg.to
# 2013/03/16 fc2.com{{{
# seed値はswfdumpで抽出
# 落とす時はginfo.phpにアクセスした時のuseragentと同じでないと弾かれるので
# web_fetch関数に使ったダウンローダと動画プレイヤーのuseragentを合わせておくように
get_fc2(){
    mdl_support "${1}" '^(../)?(a/)?content/[0-9]+[0-9a-zA-Z]+(&|$).*$'
    local fc2_seed='gGddgPfeaf_gzyr'
    local fc2_part="`web_fetch "${1}"|\
    grep -E -o '<param name="FlashVars"[^>]*'|grep -E -o 'value="[^"]*'|sed -e 's/value="//' -e 's/\&/\n/g'`"
    local fc2_i="`echo "${fc2_part}"|grep '^i='|sed 's/^i=//'`"
    local fc2_mimi="`printf "${fc2_i}_${fc2_seed}"|md5sum|grep -E -o '^[^ ]*'`"
    web_fetch "http://video.fc2.com/ginfo.php?mimi=${fc2_mimi}&v=${fc2_i}&upid=${fc2_i}"|sed -e 's/^filepath=//'|grep -E -o '^.*&mid=[^&]*'|sed -e 's/\&/?/g'
}
# }}}fc2.com
# 2013/03/16 youporn.com{{{
# 複数の画質があるので|head -1 などをして1つにしてから動画プレイヤーに渡してください
get_youporn(){
    mdl_support "${1}" '^watch/[0-9]+/.*$'
    web_fetch "${1}"|\
    sed -ne '/<ul class="downloadList">/,/<\/ul>/p'|\
    grep -E -o '<a href="[^"]*'|\
    sed -e 's/<a href="//g' -e 's/\&amp;/\&/g'
}
# }}}youporn.com
# 2013/03/16 himado.in{{{
# urlの下にセレクトメニューに書いてある文字列が表示されます
# 既にセレクト済みのurlを渡すと表示されるurlは1つだけでメニューの文字列は表示されません
# 複数表示された場合は直接urlをコピペするか
# 2>&1|grep -B 1 'セレクトメニューに書いてある文字列'|head -1
# こんな感じのコマンドを後ろにつけて実行すればいいです
get_himado(){
    echo "${1#*//*/}"|grep -E '^\?id=[0-9]+&(sid|def)=[0-9]+$' >/dev/null 2>&1
    if [ "${?}" == '0' ];then
        web_fetch "${1}"|\
        grep -E -o 'movie_url = "http[^"]*'|\
        sed -s 's/^movie_url.*"//'|\
        nkf --url-input
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
}
# }}}himado.in
# 2013/03/16 momovideo.net{{{
# urlの下にセレクトメニューに書いてある文字列が表示されます
get_momovideo(){
    mdl_support "${1}" '^\?watchId=[0-9]+$'
    local momovideo_source="`web_fetch "${1}"`"
    local momovideo_default="`echo "${momovideo_source}"|\
    grep -E -o "mediaUrl=http[^']*"|\
    sed -e 's/^mediaUrl=//'`"
    local momovideo_sub="`echo "${momovideo_source}"|\
    grep -E '<select name="media_url".*</select>'|\
    grep -E -o '<option value="[^<]*'|\
    sed -e 's/^<option value="//g'`"
    IFS=$'\n'
    for momovideo_tmp in `echo "${momovideo_default}${momovideo_sub}"`;do
        echo "${momovideo_tmp%%\"*}"
        echo -e "${momovideo_tmp#*>}\n" >&2
    done
}
# }}}momovideo.net
# 2013/03/16 dailymotion.com{{{
# 画質が複数あります
get_dailymotion(){
    mdl_support "${1}" '^video/[0-9a-zA-Z_-]+$'
    web_fetch "${1}"|\
    grep -E -o 'sequence":"[^"]*'|\
    nkf --url-input|\
    grep -E -o '"(ld|sd|hq|hd720)URL":"[^"]*'|\
    sed -e 's/^"[^"]*URL":"//g' -e 's|\\/|/|g'
}
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
get_ted(){
    mdl_support "${1}" '^talks/[0-9a-zA-Z_]+\.html$'
    local ted_source="`web_fetch "${1}"`"
# httpのurl
    echo "${ted_source}"|\
    grep -E -o '<a id="no-flash-video-download" href="[^"]*'|\
    sed -e 's/^<a id="no-flash-video-download" href="//'
# rtmpのurl
    local ted_flashvars="`echo "${ted_source}"|\
    grep -E -o '"flashVars":{[^}]*'|\
    grep -E -o '"playlist":"[^"]*'|\
    nkf --url-input|\
    sed -e 's|\\\\/|/|g'`"
    local ted_host="`echo "${ted_flashvars}"|\
    grep -E -o '"streamer":"[^"]*'|sed -e 's/^"streamer":"//'`"
    for ted_path in `echo "${ted_flashvars}"|grep -E -o '"mp4:[^"]*'|sed -e 's/^"mp4://'`;do
        echo "${ted_host}/${ted_path}"
    done
}
# }}}ted.com
# 2013/03/17 ustream.tv{{{
# リダイレクト先が動画がへのパス
get_ustream(){
# /recorded/[0-9]+${{{
    echo "${1#*//*/}"|grep -E '^recorded/[0-9]+$' >/dev/null 2>&1
    if [ "${?}" == '0' ];then
        echo "http://tcdn.ustream.tv/video`echo "${1}"|grep -E -o '/[0-9]+$'`"
# }}}/recorded/[0-9]+$
# /channel/.+${{{
# 同じurlがあるのは仕様です
# rtmpdumpに渡す形式で出力されます
# mplayerで再生するならば
# eval rtmpdump -v -q -o - "`mdl.sh 'ustreamのurl'|head -1`" |mplayer -
# こんな感じで使用できます
# たまに再生できない動画があるのは仕様です
    else
        mdl_support "${1}" '^channel/.+$'
        local ustream_cid="`web_fetch "${1}"|\
        grep -E -o 'cid=[0-9]+'|\
        head -1|\
        sed -e 's/^cid=//'`"
        local ustream_amf="`web_fetch "http://cdngw.ustream.tv/Viewer/getStream/1/${ustream_cid}.amf"|\
        strings`"
# cdn{{{
    ustream_rtmp="`echo "${ustream_amf}"|\
        grep -E '^(akamai|stream_live|.+rtmp:\/\/.*(fplive.net|edgefcs.net)/).+$'`"
        local ustream_flag='0'
        IFS=$'\n'
        for ustream_tmp in ${ustream_rtmp};do
            echo "${ustream_tmp}"|\
            grep -E '^.*rtmp:\/\/.+$' >/dev/null 2>&1
            if [ "${?}" == 0 ];then
                local ustream_url="${ustream_tmp#*rtmp:}"
            else
                local ustream_path="${ustream_tmp}"
            fi
            if [ "${ustream_flag}" == '1' ];then
                echo "-s 'http://www.ustream.tv/flash/viewer.swf' -r 'rtmp:${ustream_url}/${ustream_path}'"
                local ustream_flag='0'
                continue
            fi
            local ustream_flag='1'
        done
# }}}cdn
# fms{{{
        local ustream_rtmp="`echo "${ustream_amf}"|\
        grep -E -o 'rtmp://.+/ustreamVideo/[0-9]+'`"
        if [ -n "${ustream_rtmp}" ];then
            echo "-s 'http://www.ustream.tv/flash/viewer.swf' -r '${ustream_rtmp}' -a 'ustreamVideo/${ustream_rtmp##*/}' -y 'streams/live'"
        fi
# }}}fms
# }}}/channel/.+$
    fi
}
# }}}ustream.tv
# 2013/03/18 *.nicovideo.jp{{{
# ログインが必要なサービスなので最初にidとpwを要求します
get_nicovideo(){
    local nicovideo_cookies='/tmp/mdl_cookies_nicovideo.txt'
# www.nicovideo.jp{{{
# 動画のダウンロードにcookieが必要なので例えばmplayerで再生するなら
# mplayer -cookies -cookies-file ${nicovideo_cookies}" "`mdl.sh 'ニコニコ動画のurl'`"
# だいたいこんな感じで再生が可能です
# そういうわけで標準出力をする時はcookieの分も出力しています。なので
# eval mplayer "`mdl.sh ニコニコ動画のurl`"
# 再生する時はこんな感じになります
    echo "${1#*//}"|grep -E '^www\..+' >/dev/null 2>&1
    if [ "${?}" == '0' ];then
        mdl_support "${1}" '^watch/.+$'
        nicovideo_login "${1}" 'niconico' "${nicovideo_cookies}"> /dev/null
        local nicovideo_url="`wget --quiet --load-cookies="${nicovideo_cookies}" -O - "http://flapi.nicovideo.jp/api/getflv?v=${1#*/watch/}"|\
        grep -E -o 'url=[^&]+'|\
        sed -e 's/^url=//'|\
        nkf --url-input`"
        echo "-cookies -cookies-file '${nicovideo_cookies}' '${nicovideo_url}'"
# }}}www.nicovideo.jp
# live.nicovideo.jp{{{
# rtmpdumpに渡す形式で出力されます
# eval rtmpdump "`mdl.sh 'ニコニコ生放送のURL'|head -1`" rtmpdumpの使いたいパラメータ
# といった感じで使用できます
    else
        mdl_support "${1}" '^watch/.+$'
        local nicovideo_source="`nicovideo_login "${1}" 'nicolive' ''|\
        nkf --url-input|\
        grep 'getplayerstatus'`"
        local nicovideo_provider="`echo "${nicovideo_source}"|\
        grep -E -o '<provider_type>[^<]+'|sed -e 's/<provider_type>//'`"
        case "${nicovideo_provider}" in
# 公式生放送{{{
# 何もいじっていないrtmpdumpでも動作可能
# urlにはpremiumやmobileやdefault用など複数の種類があるので種類はurlの下に >&2 で表示しています
# そういうわけでその情報を利用して選択するならば
# mdl.sh 'ニコニコ生放送のURL' 2>&1|grep -B 1 '^premium'|head -1
# このような感じで絞れますが簡易的なログイン画面もgrepに持っていかれるので注意
            'official')
                echo "${1#*//*/}"|grep -E '^watch/lv.+$' >/dev/null 2>&1
                if [ "${?}" == '0' ];then
                    local nicovideo_list="`echo "${nicovideo_source}"|\
                    grep -E -o '<contents id="main"[^<]+'|sed -e 's/^<contents[^>]+>//'`"
                    echo "${nicovideo_list}"|\
                    grep -E '^.*>case:' > /dev/null 2>&1
                    if [ "${?}" == '0' ];then
                        local nicovideo_list="`echo "${nicovideo_list}"|\
                        sed -e 's/^.*>case://' -e 's/,/\n/g'|\
                        nkf --url-input|\
                        sed -e 's|,|/|g'`"
                    else
                        local nicovideo_list="`echo "${nicovideo_list}"|\
                        sed -e 's/^.*>//'|\
                        sed -e 's|,|/|g'`"
                    fi
                    IFS=$'\n'
                    for nicovideo_tmp in ${nicovideo_list};do
                        local nicovideo_url="`echo "${nicovideo_tmp}"|\
                        grep -E -o 'rtmp://.+$'`"
                        local nicovideo_url="${nicovideo_url}?$(echo "${nicovideo_source}"|grep -E -o "<stream name=\"${nicovideo_url##*/}\">[^<]+"|sed -E -e 's/^<[^>]+>//' -e 's/\&amp\;/\&/g')"
                        echo "-r '${nicovideo_url}' -C 'S:${nicovideo_url##*/}'"
                        echo "${nicovideo_tmp}"|\
                        grep -E -o '^[^:]+:[^:]+:' >&2
                        echo >&2
                    done
                else
# この条件に当てはまるのはnsenなど
# 気が向いたら書く
                    echo "unsupport live: ${1}"
                    exit 0
                fi
                ;;
# }}}公式生放送
# ユーザーもしくはチャンネル{{{
# -Nオプションが使える(ニコニコ生放送に対応した)rtmpdumpでないと使用不可
# linux版は
# https://github.com/taonico/rtmpdump-nico-live
# これを参考にpatchを書けば動きます
            'community'|'channel')
                echo "${nicovideo_source}"|grep -E '<que ?[^>]*>' >/dev/null 2>&1
                if [ "${?}" == '0' ];then
## FIXME:タイムシフトの場合 (よくわからないので未実装)
                    local nicovideo_ticket="`echo "${nicovideo_source}"|\
                    grep -E -o '<ticket[^<]+'|\
                    sed -E -e 's/.+>//'`"
                    local nicovideo_list="`echo "${nicovideo_source}"|\
                    grep -E -o '<que [^/]*/publish[^<]*'|\
                    grep -E -o 'rtmp://.*'|\
                    sed -e 's|,|/|g'`"
                    for nicovideo_rtmp in ${nicovideo_list};do
                        echo "-r '${nicovideo_rtmp}' -C 'S:${nicovideo_ticket}'"
                    done
                else
# 通常の生放送
                    local nicovideo_n="`echo "${nicovideo_source}"|\
                    grep -E -o '<contents id="main"[^<]+'|\
                    sed -E -e 's/.+>rtmp://'`"
                    local nicovideo_url="`echo "${nicovideo_source}"|\
                    grep -E -o '<url[^<]+'|\
                    sed -E -e 's/.+>//'`"
                    local nicovideo_ticket="`echo "${nicovideo_source}"|\
                    grep -E -o '<ticket[^<]+'|\
                    sed -E -e 's/.+>//'`"
                    echo "-r '${nicovideo_url}' -C 'S:${nicovideo_ticket}' -N '${nicovideo_n}'"
                fi
                ;;
# }}}ユーザーもしくはチャンネル
            *)
                echo "unsupport provider type:${nicovideo_provider} url:${1}" >&2
                exit 1
                ;;
        esac
# }}}live.nicovideo.jp
    fi
}
# }}}*.nicovideo.jp
# 2013/03/21 justin.tv and twitch.tv{{{
# mplayerで再生するには
# eval rtmpdump -v -q -o - "`mdl.sh justin.tvのURL`"|mplayer-
# こんな感じです
get_justin(){
    local justin_source="`web_fetch "http://usher.justin.tv/find/${1##*/}.xml?type=any"`"
    local justin_rtmp_list="`echo "${justin_source}"|grep -E -o '<connect>[^<]+'|sed -e 's/^<connect>//'`"
    local justin_token_list="`echo "${justin_source}"|grep -E -o '<token>[^<]+'|sed -e 's/^<token>//'`"
    local justin_play_list="`echo "${justin_source}"|grep -E -o '<play>[^<]+'|sed -e 's/^<play>//'`"
    local justin_i='1'
    local justin_rtmp="`echo "${justin_rtmp_list}"|sed -n "${justin_i}p"`"
    local justin_token="`echo "${justin_token_list}"|sed -n "${justin_i}p"`"
    local justin_play="`echo "${justin_play_list}"|sed -n "${justin_i}p"`"
    while [ -n "${justin_rtmp}" ] ;do
        echo "-r '${justin_rtmp}/${justin_play}' -j '${justin_token}' -s 'http://www-cdn.jtvnw.net/widgets/live_site_player.swf'"
        local justin_i="`expr "${justin_i}" + 1`"
        local justin_rtmp="`echo "${justin_rtmp_list}"|sed -n "${justin_i}p"`"
        local justin_token="`echo "${justin_token_list}"|sed -n "${justin_i}p"`"
        local justin_play="`echo "${justin_play_list}"|sed -n "${justin_i}p"`"
    done
}
# }}}justin.tv and twitch.tv
# 2013/03/21 redtube.com {{{
get_redtube(){
    mdl_support "${1}" '^[0-9]+$'
    web_fetch "${1}"|\
    grep -E -o "<source src='[^']+"|sed -E -e "s/^[^']+'//"
}
# }}}redtube.com
# 2013/03/21 radiko.jp{{{
# 視聴できる全てのラジオが出力されるので
# mdl.sh 'http://radiko.jp'|grep MBS
# このように絞って使用します
# mplayerで聴きたい場合は
# eval rtmpdump -q -v -o - "`mdl.sh 'http://radiko.jp'|grep MBS`"|mplayer -
# こんな感じです
get_radiko(){
    local radiko_player='http://radiko.jp/player/swf/player_3.0.0.01.swf'
    local radiko_swf='/tmp/mdl_radiko_player.swf'
    local radiko_jpg='/tmp/mdl_radiko_player.jpg'
    wget --quiet -O "${radiko_swf}" "${radiko_player}"
    swfextract -b 14 "${radiko_swf}" -o "${radiko_jpg}"
    local radiko_auth="`wget --quiet -O - \
    --header="pragma: no-cache" \
    --header="X-Radiko-App: pc_1" \
    --header="X-Radiko-App-Version: 2.0.1" \
    --header="X-Radiko-User: test-stream" \
    --header="X-Radiko-Device: pc" \
    --post-data='\r\n' \
    --no-check-certificate \
    --save-headers \
    'https://radiko.jp/v2/api/auth1_fms'|\
    sed -e 's/\r//g'`"
    local radiko_token="`echo "${radiko_auth}"|\
    grep -E -o 'X-RADIKO-AUTHTOKEN=.+'|\
    sed -E -e 's/^[^=]+=//'`"
    local radiko_offset="`echo "${radiko_auth}"|\
    grep -E -o 'X-Radiko-KeyOffset=.+'|\
    sed -E -e 's/^[^=]+=//'`"
    local radiko_length="`echo "${radiko_auth}"|\
    grep -E -o 'X-Radiko-KeyLength=.+'|\
    sed -E -e 's/^[^=]+=//'`"
    local radiko_key="`dd if="${radiko_jpg}" bs=1 skip="${radiko_offset}" count="${radiko_length}" 2>/dev/null|base64`"
    radiko_area="`wget --quiet -O - \
    --header="pragma: no-cache" \
    --header="X-Radiko-App: pc_1" \
    --header="X-Radiko-App-Version: 2.0.1" \
    --header="X-Radiko-User: test-stream" \
    --header="X-Radiko-Device: pc" \
    --header="X-Radiko-Authtoken: ${radiko_token}" \
    --header="X-Radiko-Partialkey: ${radiko_key}" \
    --post-data='\r\n' \
    --no-check-certificate \
    'https://radiko.jp/v2/api/auth2_fms'|\
    sed -e 's/\r//g'|\
    grep ','`"
    local radiko_id="`web_fetch "http://radiko.jp/v2/station/list/${radiko_area%%,*}.xml"|\
    grep -E -o '<id>[^<]+'|sed -e 's/^<id>//'`"
# この方法でrtmpeプロトコルのurlを取得するが、固定なのでわざわざ取得しない
#    for radiko_tmp in ${radiko_id};do
#        web_fetch "http://radiko.jp/v2/station/stream/${radiko_tmp}.xml"|\
#        grep -E -o 'rtmpe://[^<]+'|head -n 1
#    done
    for radiko_tmp in ${radiko_id};do
        echo "-r 'rtmpe://w-radiko.smartstream.ne.jp' -a '${radiko_tmp}/_definst_' -y 'simul-stream.stream' -C 'S:' -C 'S:' -C 'S:' -C 'S:${radiko_token}'"
    done
    rm "${radiko_swf}" "${radiko_jpg}"
}
# }}}radiko.jp
# }}}get_*
# }}}関数群
# メインルーチン{{{
# urlか判定{{{
echo "${1}"|grep -e '^http://' -e '^https://' >/dev/null 2>&1
if [ "${?}" == '1' ];then
    echo "not url: ${1}" >&2
    exit 1
fi
# }}}urlか判定
# サイトの場合分け{{{
case `echo "${1}"|cut -d '/' -f 3` in
    'www.youtube.com')
        get_youtube "${1}"
        ;;
    'www.xvideos.com'|'www.xvideos.jp')
        get_xvideos "${1}"
        ;;
    'www.tokyo-porn-tube.com'|'www.tokyo-tube.com')
        get_tokyotube "${1}"
        ;;
    'asg.to')
        get_asg "${1}"
        ;;
    'video.fc2.com')
        get_fc2 "${1}"
        ;;
    'www.youporn.com')
        get_youporn "${1}"
        ;;
    'himado.in')
        get_himado "${1}"
        ;;
    'momovideo.net')
        get_momovideo "${1}"
        ;;
    'www.dailymotion.com')
        get_dailymotion "${1}"
        ;;
    'www.ted.com')
        get_ted "${1}"
        ;;
    'www.ustream.tv')
        get_ustream "${1}"
        ;;
    'live.nicovideo.jp'|'www.nicovideo.jp')
        get_nicovideo "${1}"
        ;;
    'www.twitch.tv'|*'.justin.tv')
        get_justin "${1}"
        ;;
    'www.redtube.com')
        get_redtube "${1}"
        ;;
    'radiko.jp')
        get_radiko
        ;;
    *)
        echo "unknown site: ${1}" >&2
        ;;
esac
# }}}サイトの場合分け
# }}}main
# vim:set fdm=marker:
