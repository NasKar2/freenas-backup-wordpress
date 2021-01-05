# freenas-backup-wordpress
Script to backup, restore and migrate Wordpress data. Backup files are stored under your pool in the subdirectory `backup` by default.

The script will work with any WordPress data source, however, setting it up is much simpler if you've installed WordPress using https://github.com/basilhendroff/freenas-iocage-wordpress

## Status
This script will work with FreeNAS 11.3, and it should also work with TrueNAS CORE 12.0.  Due to the EOL status of FreeBSD 11.2, it is unlikely to work reliably with earlier releases of FreeNAS.

## Usage

### Prerequisites
The backup script assumes that your WordPress data is kept outside the WordPress jail.
- You must have a working Wordpress install to use this script.
- You need to have a file /root/<JAIL_NAME>_db_password.txt containing the DB_PASSWORD if MariaDB ver 10.4 or higher. If less than 10.4 you also need the DB_ROOT_PASSWORD in the file.
More details can be found in the MariaDB Versions section.

### Installation
Download the repository to a convenient directory on your FreeNAS system by changing to that directory and running `git clone https://github.com/naskar2/freenas-backup-wordpress`.  Then change into the new `freenas-backup-wordpress` directory.

### Setup
If you've used the previously mentioned install script and accepted the default WordPress jail name `wordpress`, additional setup isn't necessary for the backup script to run. If you have changed the jail name, or have installed WordPress using another method, then create a file called `backup-config` with your favorite text editor.  In its minimal form, it would look something like this:

```
JAIL_NAME="wp-blog"
```
All options have sensible defaults, which can be adjusted if needed. These are:

- JAIL_NAME: The name of the jail, defaults to `wordpress`. Can be multiple jails separated by a space. Or you can specify jails after the script name separated by a space to overide the setting in backup-config
- BACKUP_PATH: Backups are stored in this location. Default is the subdirectory `backup` under the pool path.
- APPS_PATH: Location of apps folder. Will be set automatically by finding wordpress installs. Set only if installs have different root directories. See example #6.
  If you installed wordpress in the root of the pool `/mnt/v1` the script will not be able to automatically detect it.
  Set `APPS_PATH="/"` which will leave it blank in the script. See example #7
- FILE_PATH: Location of wordpress files. '/' if `pool/apps/wordpress/`. Or 'files' if `pool/apps/wordpress/files/`
- DATABASE_NAME: Defaults to `wordpress`
- DB_NAME: The name of your WordPress database. Defaults to `wordpress`.
- JAIL_FILES_LOC: Location of wordpress files in the jail.  Default is `/usr/local/www/wordpress`
- MAX_NUM_BACKUPS: The maximum number of backups to keep. If not set will be unlimited. If set to 2 only the latest 2 backups will be kept.

Some examples follow:

#### 1. *'I've used the install script, and accepted the default jail name of `wordpress`.'*
A backup-config is not required.

#### 2. *'I'm using the WordPress jail name `personal`.'*
backup-config:
```
JAIL_NAME="personal"
```
Note: be aware that the jail name is case sensitive.

#### 3. *`I also want my backups stored in the pool under a temp root.'* Will be stored in /mnt/tank/temp/personal/
```
JAIL_NAME="personal"
BACKUP_PATH="temp"
```

#### 4. *'I haven't used the install script.
backup-config:
```
JAIL_NAME="personal"
BACKUP_PATH="/mnt/tank/backup/personal"
```

Create the file /root/personal_db_password.txt with
If MariaDB version >= 10.4
```
DB_PASSWORD="alakazam"
```

If MariaDB version < 10.4
```
DB_ROOT_PASSWORD="abracadabra"
DB_PASSWORD="alakazam"
```

#### 5. *'I want to backup multiple sites (wordpress and personal) at the same time'*
```
JAIL_NAME="wordpress personal"
```
or

Execute the command `script backup.log ./backup.sh wordpress personal`

#### 6. *'I have 2 wordpress installs at different root directories'*

One at `/mnt/v1/apps/wordpress/files` and another at `/mnt/v1/apps/wordpress/Site1/files`.

The JAIL names are `wordpress` and `Site 1` respectively.

The root directories are `/mnt/v1/apps` and `/mnt/v1/apps/wordpress` respectively.

You have to pick one or the other because the root directories are different. Will pick the 2nd one.
```
JAIL_NAME="Site1"
APPS_PATH="apps/wordpress"
```

#### 7. *'I have install wordpress in the pool root directory'*

The JAIL name is "apple" and was installed to '/mnt/v1/apple' where the pool is '/mnt/v1'.
```
JAIL_NAME="apple"
APPS_PATH="/"
```

## Backup
Once you've prepared the configuration file (if required), and the <JAIL_NAME>_db_password.txt file, run the script `script backup.log ./backup.sh`. You will be prompted to (B)ackup or (R)estore. Choose backup. 
After choosing 'B' wordpress will be placed in maintenance mode temporarily till the backup is completed.
This will prevent any changes from occurring during the backup process.
The script will keep unlimited backups unless you add the MAX_NUM_BACKUPS to the backup-config.
If you set MAX_NUM_BACKUPS to 2 it will delete all backups except for the 2 most recent ones. 
To automate backup, create a cron job pointing to the backup script. The prompts wll be bypassed in any non-interactive operation like a cron task in the FreeNAS GUI.

## Restore
**WARNING: A restore overwrites any existing WordPress data!!!**

Once you've prepared the configuration file (if required), and the <JAIL_NAME>_db_password.txt file, run the script `script backup.log ./backup-jail.sh`.
You will be prompted to (B)ackup or (R)estore. Choose restore.
After choosing 'R' wordpress will be placed in maintenance mode temporarily till the restore is completed.  
This will prevent any changes from occurring during the restore process.
You will get a list of backups to choose from. Pick the one with the date stamp you want to restore.
**If you get an error "Error establishing a database connection." that means you are trying to restore a backup with a different password than your current install.
You will need to do a do a Migration instead and set the OLD_IP and NEW_IP to same IP address. See Migrate section below.**

## Migrate
**WARNING: A restore overwrites any existing WordPress data!!!**

Once you've prepared the configuration file (see examples below), run the script `script backup.log ./backup.sh`. You will be prompted to (B)ackup or (R)estore. Choose restore.
**Your wordpress.tar.gz file must be in the <POOL_PATH>/<BACKUP_PATH>/<JAIL_NAME> directory**

Migration can be done specifying the old and new IPs and old and new gateways. See examples below.
These parameters will be removed from the backup-config after the restore is complete as migration only needs to run once.
Data needs to be changed to match your requirements. Remember the password to access the web interface will change back to the password of the restored backup.

**Migrate IP**
```
BACKUP_NAME="wordpress.tar.gz"
DATABASE_NAME="wordpress"
OLD_IP="192.168.5.76"
NEW_IP="192.168.5.77"
```

**Migrate IP and Gateway**
```
BACKUP_NAME="wordpress.tar.gz"
DATABASE_NAME="wordpress"
OLD_IP="192.168.5.76"
NEW_IP="192.168.1.77"
OLD_GATEWAY="192.168.5.1"
NEW_GATEWAY="192.168.1.1
```

## Multiple Wordpress Jails
If you have multiple wordpress sites you can list them in JAIL_NAME variable separated by a space.  Or you can state them at the end of the script name. `script backup.log ./backup-jail.sh wordpress personal`
All the listed wordpress jails will be backed up and you will be asked which one you want to restore if you have more than one. 
```
JAIL_NAME="wordpress, personal"
```

## MariaDB Versions
The script checks for the version of MariaDB in you jail install.  If 10.4 or higher using the default Authenication Plugin, no DB_ROOT_PASSWORD is needed in the {JAIL}_db_password.txt.
If 10.3 or lower using the default Authenication Plugin, it requires a DB_ROOT_PASSWORD and DB_PASSWORD in the {JAIL}_db_password.txt.
Ideally it would be best to create a test for the Authentication Plugin but I'm not aware of how to do this test at this time.

## Support and Discussion
Reference: [WordPress Backups](https://wordpress.org/support/article/wordpress-backups/)

Questions or issues about this resource can be raised in [this forum thread](https://www.ixsystems.com/community/threads/wordpress-backup-restore-and-migrate-script.87776/). Support is limited to getting the backup script working with your WordPress jail. 

## Disclaimer
It's your data. It's your responsibility. This resource is provided as a community service. Use it at your own risk.

