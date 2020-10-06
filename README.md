# freenas-backup-wordpress
Script to backup, restore and migrate Wordpress data. Backup files are stored under your WordPress root in the subdirectory `backup`.

The script will work with any WordPress data source, however, setting it up is much simpler if you've installed WordPress using https://github.com/basilhendroff/freenas-iocage-wordpress

## Status
This script will work with FreeNAS 11.3, and it should also work with TrueNAS CORE 12.0.  Due to the EOL status of FreeBSD 11.2, it is unlikely to work reliably with earlier releases of FreeNAS.

## Usage

### Prerequisites
The backup script assumes that your WordPress data is kept outside the WordPress jail.

### Installation
Download the repository to a convenient directory on your FreeNAS system by changing to that directory and running `git clone https://github.com/naskar2/freenas-backup-wordpress`.  Then change into the new `freenas-backup-wordpress` directory.

### Setup
If you've used the previously mentioned install script and accepted the default WordPress jail name `wordpress`, additional setup isn't necessary for the backup script to run. If you have changed the jail name, or have installed WordPress using another method, then create a file called `backup-config` with your favorite text editor.  In its minimal form, it would look something like this:

```
JAIL_NAME="wp-blog"
```
All options have sensible defaults, which can be adjusted if needed. These are:

- JAIL_NAME: The name of the jail, defaults to `wordpress`.
- BACKUP_PATH: Backups are stored in this location. Default is the subdirectory `backup` under the pool path.
- DB_ROOT_PASSWORD: Password for DB user root. Default is to read this from /root/wordpress_db_password.txt if the install script was used.
- DB_PASSWORD: Password for DB user. Default is to read this from /root/wordpress_db_password.txt if the install script was used. 
- DB_USER: Name of the DB user. Default assumes the user is `wordpress`.
- BACKUP_NAME: The name of the backup file. Defaults to `<JAIL_NAME>.tar.gz`. 
- DB_NAME: The name of your WordPress database. Defaults to `wordpress`.
- DB_SQL: The SQL file used used to backup/restore your WordPress database. Defaults to `wordpress.sql`.

Some examples follow:

#### 1. *'I've used the install script, and accepted the default jail name of `wordpress`.'*
A backup-config is not required.

#### 2. *'I'm using the WordPress jail name `personal`.'*
backup-config:
```
JAIL_NAME="personal"
```
Note: be aware that the jail name is case sensitive.

#### 3. *`I also want my backups stored in the pool under a backup root.'*
```
JAIL_NAME="personal"
BACKUP_PATH="/mnt/tank/backup/personal"
```

#### 4. *'I haven't used the install script. My DB user is `naskar`.*
backup-config:
```
JAIL_NAME="personal"
BACKUP_PATH="/mnt/tank/backup/personal"
DB_ROOT_PASSWORD="abracadabra"
DB_PASSWORD="alakazam"
DB_USER="naskar"
```

## Backup
Once you've prepared the configuration file (if required), run the script `script backup.log ./backup-jail.sh`. You will be prompted to (B)ackup or (R)estore. Choose backup. 

To automate backup, create a cron job pointing to the backup script. The prompts wll be bypassed in any non-interactive operation.

## Restore
**WARNING: A restore overwrites any existing WordPress data!!!**

Once you've prepared the configuration file (if required), run the script `script backup.log ./backup-jail.sh`. You will be prompted to (B)ackup or (R)estore. Choose restore.
You will be promoted to reconfirm the operation `Are you sure? (y/N)`. The default action is to abort. Enter (Y)es if you are sure you want to proceed with the restore operation.

## Migrate
**WARNING: A restore overwrites any existing WordPress data!!!**

Once you've prepared the configuration file (see examples below), run the script `script backup.log ./backup-jail.sh`. You will be prompted to (B)ackup or (R)estore. Choose restore.


## Support and Discussion
Reference: [WordPress Backups](https://wordpress.org/support/article/wordpress-backups/)

Questions or issues about this resource can be raised in [this forum thread](https://www.ixsystems.com/community/threads/wordpress-backup-restore-and-migrate-script.87776/). Support is limited to getting the backup script working with your WordPress jail. 

## Disclaimer
It's your data. It's your responsibility. This resource is provided as a community service. Use it at your own risk.


## To be  reviewed at a later stage

### Optional Migration of the wordpress

This can be done specifying the old and new IPs and old and new gateways. See examples below.
These parameters will be removed from the backup-config after the restore is complete.
Data needs to be changed to match your requirements. Remember the password to access the web interface will change back to restored backup.

**Migrate IP**
```
APPS_PATH="apps"
BACKUP_NAME="wordpress.tar.gz"
DATABASE_NAME="wordpress"
DB_BACKUP_NAME="wordpress.sql"
OLD_IP="192.168.5.76"
NEW_IP="192.168.5.77"
```

**Migrate IP and Gateway**
```
APPS_PATH="apps"
BACKUP_NAME="wordpress.tar.gz"
DATABASE_NAME="wordpress"
DB_BACKUP_NAME="wordpress.sql"
OLD_IP="192.168.5.76"
NEW_IP="192.168.1.77"
OLD_GATEWAY="192.168.5.1"
NEW_GATEWAY="192.168.1.1
```
