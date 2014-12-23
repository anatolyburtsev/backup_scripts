#!/bin/sh
set -e

backup_server="deposito"
path_to_remote_backup="antivirus/redis" 

data=`redis-cli CONFIG get dir|tail -1`
rm -f $data/dump.rdb || :
res=`redis-cli SAVE`
if [ "$res" == "OK" ]; then
    rsync $data/dump.rdb ${backup_server}::${path_to_remote_backup}/`hostname -s``date +%Y%m%d%H%M`.rdb
fi
