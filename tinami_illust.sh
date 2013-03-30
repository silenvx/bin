#!/bin/sh
# 2013/03/31に作成

save_cookies='/tmp/cookies_tinami.com.txt'

tinami_login(){
    tinami_auth="${HOME}/.login_account/tinami.com"
    if [ -f "${tinami_auth}" ];then
        tinami_mail="`sed -n '1p' "${tinami_auth}"`"
        tinami_password="`sed -n '2p' "${tinami_auth}"`"
    fi
    if [ -z "${tinami_mail}" -o -z "${tinami_password}" ];then
        printf 'tinami.com mail     > ' >&2
        read tinami_mail
        stty -echo
        printf 'tinami.com password > ' >&2
        read tinami_password
        stty echo
    fi
# ログインしたらwget先のhtmlをダウンロードできるが、urlにパラメータがあるとうまくいかない
    tinami_tmp="`wget \
    --keep-session-cookies \
    --save-cookies="${save_cookies}" \
    --post-data "action_login=true&rem=1&username=${tinami_mail}&password=${tinami_password}" \
    "https://www.tinami.com/login" \
    -O -`"
    if [ -z "`echo "${tinami_tmp}"|grep '<a href="/logout" title="ログアウト">ログアウト</a></li>'`" ];then
        echo 'ログイン失敗' >&2
        exit 1
    fi
}

tinami_fetch(){
# 既に同名のファイルがあった場合は新たに保存しない
    wget -nc --load-cookies="${save_cookies}" "$@"
}

# urlの補正{{{
tinami_url="${1}"
echo "${1}"|grep -E '^http://www.tinami.com/search/list\?prof_id=[0-9]+$' > /dev/null 2>&1
if [ "${?}" == '1' ];then
    echo "${1}"|grep -E '^http://www.tinami.com/creator/profile/[0-9]+$' > /dev/null 2>&1
    if [ "${?}" == '0' ];then
        tinami_url="`echo ${1}|sed 's|/creator/profile/|/search/list?prof_id=|g'`"
    else
        echo "unsupport url: ${1}"
        exit 1
    fi
fi
# }}}urlの補正
tinami_login
# 保存ディレクトリの生成と移動{{{
mkdir "tinami.com_${tinami_url##*=}"
cd "tinami.com_${tinami_url##*=}"
# }}}保存ディレクトリの生成と移動
tinami_index='0'
tinami_list="`tinami_fetch -O - "${tinami_url}&keyword=&search=&genrekey=&period=&offset=${tinami_index}"|\
grep -E -o '<a href="/view/[^"]+'|\
sed -e 's|^<a href="/view/||g'`"
while [ -n "${tinami_list}" ];do
# 1ページ分を全て取得{{{
echo "${tinami_index}"
    IFS=$'\n'
    for tinami_id in ${tinami_list};do
        tinami_source="`tinami_fetch -O - "http://www.tinami.com/view/${tinami_id}"`"
        for tinami_type in `echo "${tinami_source}"|grep -E -o '<img src="/img/job/view/[^.]+'|sed -e 's|^<img src="/img/job/view/||g'`;do
            case "${tinami_type}" in
                'il')
# TODO: 古い画像だと大きいサイズの画像へのリンクがあるページに飛べないので
#       tinami_img変数の最後のところで無理やり元に戻っても対応してる
                    tinami_csrf="`echo "${tinami_source}"|\
                    grep -E -o '<input type="hidden" name="ethna_csrf" value="[^"]+'|\
                    sed -e 's/^<input type="hidden" name="ethna_csrf" value="//'`"
                    tinami_img="`tinami_fetch -O - --post-data "action_view_original=true&cont_id=${tinami_id}&ethna_csrf=${tinami_csrf}" \
                    --referer "http://www.tinami.com/view/${tinami_id}" \
                    "http://www.tinami.com/view/${tinami_id}"|\
                    grep -E -o '<img src="[^"]+'|\
                    sed -e 's/^<img src="//'|\
                    grep 'http://img.tinami.com/illust'`"
                    wget --referer "http://www.tinami.com/view/${tinami_id}" "${tinami_img}"
                    ;;
                'ma')
# TODO:大きいサイズへのリンクが見当たらないので直接wget
                    wget --referer "http://www.tinami.com/view/${tinami_id}" `echo "${tinami_source}"|grep -E -o 'class="nv_body"><img src="[^"]+'|sed -e 's/^class="nv_body"><img src="//g'`
                    ;;
                'ori'|'fan')
                    continue
                    ;;
                *)
                    echo "unsupport type: ${tinami_type} url:http://www.tinami.com/view/${tinami_id}" >&2
                    ;;
            esac
        done
    done
# }}}1ページ分を全て取得
# 次のページがあるか判定{{{
    tinami_index="`expr "${tinami_index}" + 20`"
    tinami_list="`tinami_fetch -O - "${tinami_url}&keyword=&search=&genrekey=&period=&offset=${tinami_index}"|\
    grep -E -o '<a href="/view/[^"]+'|\
    sed -e 's|^<a href="/view/||g'`"
# }}}次のページがあるか判定
done

rm "${save_cookies}"

# vim:set foldmethod=marker:
