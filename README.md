# freenas-backup-wordpress
Backup and Restore Wordpress install

Works with the Wordpress install script from https://github.com/basilhendroff/freenas-iocage-wordpress

Will pull the root and user password saved from the file /root/wordpress_db_password.txt created from the install script mentioned above.

You can manually enter the DB_ROOT_PASSWORD and DB_PASSWORD in the backup-config file

## Prerequisites 

Create a config file called backup-config

```
cron=""
POOL_PATH="/mnt/v1"
APPS_PATH="apps"
BACKUP_PATH="backup"
FILES_PATH="files"
BACKUP_NAME="wordpress.tar.gz"
WORDPRESS_APP="wordpress"
DATABASE_NAME="wordpress"
DB_BACKUP_NAME="wordpress.sql"
OLD_IP=""
NEW_IP=""
OLD_GATEWAY=""
NEW_GATEWAY=""
```
Many of the options are self-explanatory, and all should be adjusted to suit your needs, but only a few are mandatory. The mandatory options are:

* POOL_PATH is the location of your pool in my setup /mnt/v1
* APPS_PATH is the location of you applications data usually /mnt/v1/apps
* BACKUP_PATH is the location to store your backups in my setup /mnt/v1/backup
* FILES_PATH is the location to the wordpress files data in my setup /mnt/v1/apps/wordpress/files.  Leave blank if the files data is in /mnt/v1/apps/wordpress
* BACKUP_NAME is the name of the backup file in my setup wordpress.tar.gz"
* WORDPRESS_APP is the name of the jail wordpress is installed in so it's data will be in /mnt/v1/apps/wordpress
* DATABASE_NAME is the name of your wordpress database
* DB_BACKUP_NAME is the name of the wordpress database files wordpress.sql

Optional parameters can be set if you didn't install wordpress with install script from https://github.com/basilhendroff/freenas-iocage-wordpress
If you used script to install wordpress, the backup script will read the /root/wordpress_db_password.txt file and place the passwords in the config file for you. 
Passwords in this document are just random examples.
**If resintalling Wordpress with new PASSWORDS delete these 2 lines from the backup-config**

* DB_ROOT_PASSWORD="8109823ojf;ljadsf;lj"
* DB_PASSWORD="lknv;asdjf72905729039"

Optional Migration of the wordpress can be done specifying the old and new IPs and old and new gateways.  These parameters will be removed after the restore is complete.
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

### Create a cron job to run the script to backup automatically without user intervention

Set cron="yes" in the backup-config

## Disclaimer
It's your data. It's your responsibility. This resource is provided as a community service. Use it at your own risk.
