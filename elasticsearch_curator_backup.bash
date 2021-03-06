#!/bin/sh
set -eu
backup_server=""
path_to_remote_backup="antivirus/elasticsearch"

curator=`which curator`
#setup snapshot for elasticsearch 
res=`curl -XGET 'http://localhost:9200/_snapshot' 2>/dev/null`

if [ "$res" == "{}" ] ; then 

curl -XPUT 'http://localhost:9200/_snapshot/my_backup' -d '{
    "type": "fs",
    "settings": {
        "location": "/place/elasticsearch/backup",
        "compress": true
    }
}'

fi

$curator --loglevel ERROR snapshot --repository my_backup --delete-older-than 1 || true
$curator --loglevel ERROR snapshot --all-indices --repository my_backup
rsync -ra /place/elasticsearch/backup ${backup_server}::${path_to_remote_backup}/`hostname -s``date +%Y%m%d%H%M`
