# Ambiguousな文字を文字幅2で/usr/share/i18n/charmaps/UTF-8.gzに
# 追加できる形式で出力するスクリプト
# 詳しくは: http://d.hatena.ne.jp/silenvx/20120929/1348930210

#!/bin/sh
FLAG_TIME='0'
FLAG_START='0'
PREV_VAL='-2'
IFS=$'\n'
for TMP1 in `wget -O - 'http://www.unicode.org/Public/UNIDATA/EastAsianWidth.txt'|grep ';A' 2>/dev/null`;do
    TMP2="${TMP1%%\#*}"
    TMP2="${TMP2%;A*}"
    echo "${TMP2}"|grep -v '\.\.' >/dev/null 2>&1
    if [ "${?}" = '0' ];then
        NOW_VAL=`printf '%d\n' 0x"${TMP2%;A*}"`
        if [ "${NOW_VAL}" == `expr "${PREV_VAL}" + 1` ];then
            END_VAL="${TMP2}"
            FLAG_TIME=`expr "${FLAG_TIME}" + 1`
        else
            if [ "${FLAG_START}" != '0' ];then
                case `echo "${#START_VAL} % 4"|bc` in
                    '0');;
                    '1')START_VAL="000${START_VAL}";;
                    '2')START_VAL="00${START_VAL}";;
                    '3')START_VAL="0${START_VAL}";;
                esac
                if [ "${FLAG_TIME}" == '0' ];then
                    echo "<U${START_VAL}> 2"
                else
                    case `echo "${#END_VAL} % 4"|bc` in
                        '0');;
                        '1')END_VAL="000${END_VAL}";;
                        '2')END_VAL="00${END_VAL}";;
                        '3')END_VAL="0${END_VAL}";;
                    esac
                    echo "<U${START_VAL}>...<U${END_VAL}> 2"
                fi
                FLAG_START='0'
                FLAG_TIME='0'
            fi
            START_VAL="${TMP2}"
            FLAG_START='1'
        fi
        PREV_VAL="${NOW_VAL}"
    else
        TMP3="${TMP2%%.*}"
        TMP4="${TMP2##*.}"
        case `echo "${#TMP3} % 4"|bc` in
            '0');;
            '1')TMP3="000${TMP3}";;
            '2')TMP3="00${TMP3}";;
            '3')TMP3="0${TMP3}";;
        esac
        case `echo "${#TMP4} % 4"|bc` in
            '0');;
            '1')TMP4="000${TMP4}";;
            '2')TMP4="00${TMP4}";;
            '3')TMP4="0${TMP4}";;
        esac
        echo "<U${TMP3}>...<U${TMP4}> 2"
    fi
done
