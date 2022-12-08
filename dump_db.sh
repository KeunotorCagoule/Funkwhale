#!/bin/bash
# Last Update : 06/12/2022
# Written by : Roulland Roxanne
# This script will dump the database and save it to a file

# Set the variables
user='gitea'
passwd='gitea_db'
db='giteadb'
name="${db}_$(date '+%y%m%d_%H%M%S')"
outputpath="/srv/db_dumps/"

# Dump the database
echo "Backup started for database - ${db}."
cd $outputpath
mysqldump -u ${user} -p${passwd} --no-tablespaces --skip-lock-tables --databases ${db} > "${name}.sql"
if [[ $? == 0 ]]
then
        tar -czf "${name}.tar.gz" "${name}.sql"
        rm -f "${name}.sql"
        echo "Backup successfully completed."
else
        echo "Backup failed."
        rm -f "${name}.sql"
        exit 1
fi