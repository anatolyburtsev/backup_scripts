#!/bin/sh
set -ex

curator --loglevel ERROR snapshot --repository my_backup --delete-older-than 1
curator --loglevel ERROR snapshot --all-indices --repository my_backup
rsync -ra /place/elasticsearch/backup deposito::antivirus/elasticsearch/`hostname -s``date +%Y%m%d%H%M`
