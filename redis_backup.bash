#!/bin/bash
set -e

backup_server="deposito"
path_to_remote_backup="antivirus/redis" 
port="6979"

data=`redis-cli -p $port CONFIG get dir|tail -1`
rm -f $data/dump.rdb 2>/dev/null || :
res=`redis-cli -p $port SAVE`
if [ "$res" == "OK" ]; then
    rsync $data/dump.rdb ${backup_server}::${path_to_remote_backup}/`hostname -s``date +%Y%m%d%H%M`.rdb
fi
