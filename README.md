# freenas-backup-wordpress
Backup and Restore Wordpress install

Works with the Wordpress install script from https://github.com/basilhendroff/freenas-iocage-wordpress

Will pull the root and user password saved from the file /root/wordpress_db_password.txt created from the install script mentioned above.

You can manually enter the DB_ROOT_PASSWORD and DB_PASSWORD in the backup-config file

## Prerequisites 

Create a config file called backup-config.  This file should be owned by root and only accessible by root user. ```chmod 600 backup-config```

```
cron=""
APPS_PATH="apps"
BACKUP_PATH="backup"
BACKUP_NAME="wordpress.tar.gz"
DATABASE_NAME="wordpress"
DB_BACKUP_NAME="wordpress.sql"
```
Many of the options are self-explanatory, and all should be adjusted to suit your needs, but only a few are mandatory. The mandatory options are:
* cron Set this variable to "yes" if you want to automate the backup. You will not get the option to restore until you set it back to blank
* APPS_PATH is the location of you applications data usually /mnt/v1/apps
* BACKUP_PATH is the location to store your backups in my setup /mnt/v1/backup
* BACKUP_NAME is the name of the backup file in my setup wordpress.tar.gz"
* DATABASE_NAME is the name of your wordpress database
* DB_BACKUP_NAME is the name of the wordpress database files wordpress.sql

### Optional Parameters

* POOL_PATH is the location of your pool in my setup /mnt/v1. It will be set automatically if left blank
* FILES_PATH is the location to the wordpress files data in my setup /mnt/v1/apps/wordpress/files.  Leave blank if the files data is in /mnt/v1/apps/wordpress. Will default to 'files'
* WORDPRESS_APP is the name of the jail wordpress is installed in so it's data will be in /mnt/v1/apps/wordpress. Will default to 'wordpress'.

### Other Optional parameters can be set if you didn't install wordpress with install script from https://github.com/basilhendroff/freenas-iocage-wordpress

If you used the [script](https://github.com/basilhendroff/freenas-iocage-wordpress) to install wordpress, the backup script will read the /root/wordpress_db_password.txt file (or tech_db_password if WORDPRESS_APP="tech"). 
If you installed wordpress without the script you must specify the password parameters below.
Passwords in this document are just random examples.
**If resintalling Wordpress without the script with new PASSWORDS update these 2 lines from the backup-config**

* DB_ROOT_PASSWORD="8109823ojf;ljadsf;lj"
* DB_PASSWORD="lknv;asdjf72905729039"

### Optional Migration of the wordpress can be done specifying the old and new IPs and old and new gateways.  These parameters will be removed after the restore is complete.
Data needs to be changed to match your requirements. Remember the password to access the web interface will change back to restored backup.

Change IP & Gateway | Change Just IP
------------------- | --------------
OLD_IP="192.168.5.77" | OLD_IP="192.168.5.77"
NEW_IP="192.168.1.78" | NEW_IP="192.168.5.78"
OLD_GATEWAY="192.168.5.1" | OLD_GATEWAY=""
NEW_GATEWAY="192.168.1.1" | NEW_GATEWAY=""

### Run a backup

Change to the directory of the script
```./backup.sh```
Select B or b to backup and R or r to restore

### Automate Backup

Create a cron job pointing to the backup.sh file and 
Set cron="yes" in the backup-config

## Disclaimer
It's your data. It's your responsibility. This resource is provided as a community service. Use it at your own risk.
