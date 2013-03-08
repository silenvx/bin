#!/bin/sh
# 2013/03/08に作成
# pixivのユーザーを指定して一括でダウンロードできます
# R-18画像をダウンロードするか否かはpixiv側の設定に依存します

save_cookies='/tmp/cookies_pixiv.net.txt'

pixiv_login(){
    printf 'pixiv.net id        > ' >&2
    read pixiv_mail
    stty -echo
    printf 'pixiv.net password  > ' >&2
    read pixiv_password
    stty echo

    wget --secure-protocol=SSLv3 \
    --keep-session-cookies \
    --save-cookies="${save_cookies}" \
    --post-data "mode=login&return_to=${1}&pixiv_id=${pixiv_mail}&pass=${pixiv_password}" \
    'https://www.secure.pixiv.net/login.php' \
    -O -
}

pixiv_fetch(){
# 既に同名のファイルがあった場合は新たに保存しない
    wget -nc --load-cookies="${save_cookies}" "$@"
}

pixiv_url="${1}"
echo "${1}"|grep -E 'http://www.pixiv.net/member_illust.php\?id=[0-9]+' > /dev/null 2>&1
if [ "${?}" == '1' ];then
    echo "${1}"|grep -E 'http://www.pixiv.net/member.php\?id=[0-9]+' > /dev/null 2>&1
    if [ "${?}" == '0' ];then
        pixiv_url="`echo ${1}|sed 's/member\.php/member_illust.php/g'`"
    else
        echo "unsupport url: ${1}"
        exit 1
    fi
fi

pixiv_source="`pixiv_login "${pixiv_url}"`"
pixiv_user="`echo "${pixiv_source}"|grep -E -o '<h1 class="user">[^<]*<'|sed -e 's/^.*>//' -e 's/<.*$//'`"
pixiv_id="`echo "${pixiv_url}"|grep -E -o '[0-9]*'`"
pixiv_list="`echo "${pixiv_source}"|grep 'image-item'|sed -e 's|</li>|\n|g'|grep 'image-item'`"
mkdir "[${pixiv_user}] (pixiv.net_${pixiv_id})"
cd "[${pixiv_user}] (pixiv.net_${pixiv_id})"
IFS=$'\n'
pixiv_index='1'
while [ -n "${pixiv_list}" ];do
    for pixiv_link in `echo ${pixiv_list}|grep -E -o '<a href="[^"]*'|sed -e 's/<a href="//g'`;do
        pixiv_link="http://www.pixiv.net${pixiv_link}"
        pixiv_view="http://www.pixiv.net/`pixiv_fetch --referer="${pixiv_url}" -O - "${pixiv_link}"|grep -E -o '<div class="works_display"><a href="[^"]*'|sed -e 's/.*<a href="//'`"
        case "`echo "${pixiv_view}"|grep -E -o -e 'big' -e 'manga'`" in
            'big')
                pixiv_image="`pixiv_fetch --referer="${pixiv_link}" -O - "${pixiv_view}"|grep -E -o '<img src="*[^"]*'|sed 's/<img src="//'`"
                pixiv_fetch --referer="${pixiv_view}" "${pixiv_image}"
                ;;
            'manga')
                for pixiv_image in `pixiv_fetch --referer="${pixiv_link}" -O - "${pixiv_view}"|grep -E -o "unshift\('[^']*"|sed -e "s/unshift('//g"`;do
                    pixiv_fetch --referer="${pixiv_view}" "${pixiv_image}"
                done
                ;;
            *)
                echo "unsupport type: ${pixiv_view}"
                ;;
        esac
    done
# 下3行は次のページに画像があるか判定するためのもの
    pixiv_index="`expr "${pixiv_index}" + 1`"
    pixiv_source="`pixiv_fetch -O - "${pixiv_url}&p=${pixiv_index}"`"
    pixiv_list="`echo "${pixiv_source}"|grep 'image-item'|sed -e 's|</li>|\n|g'|grep 'image-item'`"
done

rm "${save_cookies}"
