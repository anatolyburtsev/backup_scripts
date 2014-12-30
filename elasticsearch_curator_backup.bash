#!/bin/sh
set -eu
backup_server="deposito"
path_to_remote_backup="antivirus/elasticsearch"
curator=`which curator`

$curator --loglevel ERROR snapshot --repository my_backup --delete-older-than 1
$curator --loglevel ERROR snapshot --all-indices --repository my_backup
rsync -ra /place/elasticsearch/backup ${backup_server}::${path_to_remote_backup}/`hostname -s``date +%Y%m%d%H%M`
