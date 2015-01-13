#!/bin/bash
set -eu
#
# backup and restore cassandra, incremental backup doesn't support
# author: onotole@yandex-team.ru
# date: 3.10.2014


today=`date "+%Y%m%d"`
path_to_data="/place/cassandra/data"
path_to_commitlog="/place/cassandra/commitlog"
path_to_backup="/place/cassandra/backup" 
log="/var/log/cassandra_backup.log" 
backup_server=""
path_to_remote_backup="antivirus/cassandra" 

check_exit_code() {
        exit_code=$?
        if [ "$exit_code" -ne "0" ] ; then
                echo "$1"
                echo "exit with exitcode $exit_code"
                return 1
        fi

}

backup() {
        nodetool status 1>/dev/null 2>&1
        check_exit_code "cassandra not launch"

        #remove old snapshot
        nodetool clearsnapshot 1>$log 2>&1
        check_exit_code "couldn't delete old backup"
    rm -rf $path_to_backup
    mkdir -p $path_to_backup
    chown cassandra $path_to_backup

        #create backup
        nodetool snapshot -t backup$today 1>$log 2>&1
        check_exit_code "couldn't create backup"

        #collect all backup in one dir
        for dir in `find $path_to_data -name "backup$today"`; do 
                mv -f $dir ${path_to_backup}/`echo $dir|sed -e s'\/\%%\g'`
        done

        #save backup
        rsync -rq $path_to_backup ${backup_server}::${path_to_remote_backup}/`hostname -s`$today 1>$log 2>&1
        check_exit_code "couldn't save backup on $backup_server"
    
    #delete local backup
    rm -rf $path_to_backup
}

restore() {
    #http://www.datastax.com/docs/1.0/operations/backup_restore
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
    
    #stop cassandra
    service cassandra stop 
    #remove old db files
    rm -rf $path_to_commitlog/*
    find $path_to_data -type f -name "*.db" -delete  

        #download backup and put it in right places
        rm -rf $path_to_backup/restore
        rsync -qr ${backup_server}::${path_to_remote_backup}/$day/backup $path_to_backup/restore
        for dir in $path_to_backup/restore/backup/*; do
        dst=`echo $dir|sed -e 's%.*/%%' -e 's/snapshot.*//g' -e 's\%%\/\g'`
        mkdir -p $dst
                mv -f $dir/* $dst/
        done
    chown -R cassandra:cassandra $path_to_data
        start cassandra service cassandra start
    check_exit_code "coudn't start cassandra"
         

}

if [ "`id -u`" -ne "0" ]; then
    echo "need root's permissions"
    exit 1
fi

if [ "$1" = "backup" ] ; then
        backup
elif [ "$1" = "restore" ] && [ "$2" != "" ]; then
        restore $2
else
        echo "use $0 {backup|restore day}"
fi
