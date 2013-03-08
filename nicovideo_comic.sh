#!/bin/sh
# 2013/03/05に作成
# ニコニコ静画のマンガを指定して一括でダウンロードできます

save_cookies='/tmp/cookies_nicovideo.jp.txt'

nicovideo_login(){
    printf 'nicovideo.jp mail       > ' >&2
    read nicovideo_mail
    stty -echo
    printf 'nicovideo.jp password   > ' >&2
    read nicovideo_password
    stty echo
    wget --secure-protocol=SSLv3 \
    --keep-session-cookies \
    --save-cookies="${save_cookies}" \
    --post-data "next_url=${1#*nicovideo.jp}&mail=${nicovideo_mail}&password=${nicovideo_password}" \
    'https://secure.nicovideo.jp/secure/login?site=seiga' \
    -O -
}

nicovideo_fetch(){
    wget --load-cookies="${save_cookies}" "$@"
}

echo "${1}"|egrep 'http://seiga.nicovideo.jp/comic/[0-9]+' > /dev/null 2>&1
if [ "${?}" == '1' ];then
    echo "unsupport url: ${1}"
    exit 1
fi

comic_source="`nicovideo_login "${1}"`"
comic_title="`echo "${comic_source}"|grep -A 1 '<h1'|tail -n 1|sed -e 's/ //g'`"
comic_author="`echo "${comic_source}"|grep -A 1 '<h3'|tail -n 1|sed -e 's/ //g' -e 's/^作者://'`"
comic_id="`echo "${1}"|egrep -o '[0-9]+'`"
mkdir "[${comic_author}] ${comic_title} (seiga.nicovideo.jp_comic_${comic_id})"
cd "[${comic_author}] ${comic_title} (seiga.nicovideo.jp_comic_${comic_id})"
IFS=$'\n'
for comic_episode in `echo "${comic_source}"|grep '<div class="episode"'`;do
    comic_episode_url="http://seiga.nicovideo.jp`echo "${comic_episode}"|egrep -o '<a href="[^"]*'|head -1|sed -e 's/<a href="//'`"
    comic_episode_source="`nicovideo_fetch -O - "${comic_episode_url}"`"
    comic_episode_title="`echo "${comic_episode_source}"|egrep -o '<h1><[^<]*'|sed -e 's/[^>]*>[^>]*>//'`"
    comic_episode_id="`echo "${comic_episode_url}"|sed -e 's|.*nicovideo.jp/watch/||' -e 's/?.*//'`"
    comic_episode_number="`echo "${comic_episode}"|egrep -o 'data-number="[^"]*'|egrep -o '[0-9]*'`"
    for comic_episode_image in `echo "${comic_episode_source}"|egrep -o 'http:\/\/lohas.nicoseiga.jp\/thumb\/[0-9]*p'`;do
        comic_filename="${comic_episode_number}_${comic_episode_id}_${comic_episode_title}_${comic_episode_image#*/thumb/}"
        nicovideo_fetch -O "${comic_filename}" "${comic_episode_image}"
    done
done

rm "${save_cookies}"
