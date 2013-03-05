#!/bin/sh
cddb_server='freedbtest.dyndns.org:80:/~cddb/cddbutf8.cgi'

if [ "${#}" != '1' ];then
    echo "引数にcdのデバイスファイルを指定してください"
    exit 1
fi

sudo cdrdao read-cd --device "${1}" --with-cddb --cddb-servers "${cddb_server}" --datafile CDImage.bin CDImage.toc

cueconvert -i toc -o cue CDImage.toc CDImage.cue
printf "`cat CDImage.cue`\n"|sed 's/CDImage\.bin/CDImage\.wav/g' > CDImage.cue.tmp
mv CDImage.cue.tmp CDImage.cue
sox -t cdda CDImage.bin CDImage.wav
flac CDImage.wav
metaflac --set-tag-from-file="CUESHEET=CDImage.cue" CDImage.flac
