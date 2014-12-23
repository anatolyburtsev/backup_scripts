#!/bin/bash
# DO NOT USE IT!!!
# USE VERSION WITH CURATOR

today=`date "+%Y%m%d"`
today_in_sec=`date "+%s"`
let "sec_in_day=60*60*24"
count_of_backup="1" #how many backup save locally
let "last_backup=$today_in_sec - $sec_in_day*$count_of_backup"
last_backup_name="`date --date=\"@${last_backup}\" \"+%Y%m%d\"`"
path_to_backup="/place/elasticsearch/backup/"
#if failed more shards than limit then backup stoped
failed_count_limit=2
#save by rsync
backup_server="deposito"
path_to_remote_backup="antivirus/elasticsearch"
PROGNAME=$(basename $0)
log="/var/log/${PROGNAME}.log"


check_exit_code() {
        exit_code=$?
        if [ "$exit_code" -ne "0" ] ; then
                echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2 |tee -a $log
                exit 1
        fi

}

backup() {
    date >> $log
    echo "start backup" >> $log
    if [ "`curl -XGET 'http://localhost:9200/_snapshot/my_backup?pretty' 2>/dev/null|wc -l`" -lt "2" ]; then
        echo "configure backup" >> $log
        curl -XPUT 'http://localhost:9200/_snapshot/my_backup' -d '{
            "type": "fs",
            "settings": {
                "location": "/place/elasticsearch/backup",
                "compress": true
             }
        }'
    fi
    echo "delete old backup with name current backup" >> $log
    res=`curl -XDELETE "localhost:9200/_snapshot/my_backup/snapshot_${today}"` || true
    rm -rf $path_to_backup
    install -d -o elasticsearch -g elasticsearch $path_to_backup
    echo "Start backup" >> $log
    res=`curl -XPUT "localhost:9200/_snapshot/my_backup/snapshot_${today}?wait_for_completion=true&pretty" 2>/dev/null`
    #check status SUCCESS or FAIL
    answ=`echo $res|grep -o "\"state\":\"\w*\""|grep -o "[[:upper:]]*"`
    failed_count=`echo $res|grep -A 3 '"shards" : {'|grep '"failed" :'|grep -o "[0-9]*"`
    if [ "$answ" == "SUCCESS" ] || [ "$answ" == "PARTIAL" && "$failed_count" -lt "$failed_count_limit" ]; then
        echo "Remove old backup" >> $log
            res=`curl -XDELETE "localhost:9200/_snapshot/my_backup/snapshot_${last_backup_name}"` || true
    else
        echo "failed backup with message:\n $res" | tee -a $log
        exit 1
    fi 

    rsync -rq ${path_to_backup} ${backup_server}::${path_to_remote_backup}/`hostname -s`$today

    check_exit_code "failed save on $backup_server"

}

restore() {
    echo "Are you sure? It'll delete all current data (yes/no)"
    read decision
    decision=`echo $decision|tr [:upper:] [:lower:]|cut -c 1`
    if [ "$decision" != "y" ]; then exit 1; fi
    #find right name for backup
    day=$1
    backups_count=`rsync ${backup_server}::${path_to_remote_backup}/ |grep $day|wc -l`
    if [ "$backups_count" -eq "0" ]; then
            echo "backup not found, check rsync ${backup_server}::${path_to_remote_backup}/"
            return 1
    elif [ "$backups_count" -gt 1 ]; then
            echo "choose one from $backups_count variants"
            rsync ${backup_server}::${path_to_remote_backup}/ |grep $day
            return 1
    else
            day=`rsync ${backup_server}::${path_to_remote_backup}/ |grep $day|awk '{print $NF}'`
    fi
    #download backup
    rm -rf $path_to_backup
    rsync -qr ${backup_server}::${path_to_remote_backup}/$day $path_to_backup
    check_exit_code "couldn't download backup from $backup_server"
    day=`echo $day|sed -e 's/[A-Za-z_]//g'`
    curl -XPOST  "localhost:9200/_snapshot/my_backup/snapshot_${day}/_restore"
    echo "restore complete"

}

touch $path_to_backup/test$$ &>> /dev/null
check_exit_code "fix permission on $path_to_backup or launch by root" 
rm $path_to_backup/test$$

if [ "$1" = "backup" ] ; then
        backup
elif [ "$1" = "restore" ]; then
        restore $2
else
        echo "use $0 {backup|restore day}"
fi
