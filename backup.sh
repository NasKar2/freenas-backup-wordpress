#!/bin/bash

print_msg () {
  echo
  echo -e "\e[1;32m"$1"\e[0m"
  echo
}

print_err () {
  echo -e "\e[1;31m"$1"\e[0m"
  echo
}

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   print_err "This script must be run with root privileges"
   exit 1
fi

#
# Initialize Variables
#
cron=""
POOL_PATH="/mnt/v1"
APPS_PATH="apps"
BACKUP_PATH="backup/apps"
FILES_PATH="files"
BACKUP_NAME="wordpress.tar.gz"
WORDPRESS_APP="wordpress"
DATABASE_NAME="wordpress"
DB_BACKUP_NAME="wordpress.sql"
IP_OLD=""
IP_NEW=""
OLD_GATEWAY=""
NEW_GATEWAY=""
DB_ROOT_PASSWORD=""
DB_PASSWORD=""


SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/backup-config

#
# Check if appsdir-config created correctly
#

if [ -z $POOL_PATH ]; then
  POOL_PATH="/mnt/$(iocage get -p)"
  print_msg "POOL_PATH defaulting to "$POOL_PATH
fi
if [ -z $APPS_PATH ]; then
  print_err 'Configuration error: APPS_PATH must be set'
  exit 1                                                                                                        
fi
if [ -z $FILES_PATH ]; then
  print_msg "FILES_PATH not set will default to 'files'"
  FILES_PATH="files"
fi
if [ -z $BACKUP_NAME ]; then
  print_err 'Configuration error: BACKUP_NAME must be set'
  exit 1                                                                                                        
fi
if [ -z $WORDPRESS_APP ]; then
  print_msg "WORDPRESS_APP not set so will be set to default 'wordpress'"
  WORDPRESS_APP="wordpress"
fi
if [ -z $BACKUP_PATH ]; then
   if [ ! -d "${POOL_PATH}/${APP_PATH}/${WORDPRESS_APP}/backup" ]
    then
         mkdir -p "${POOL_PATH}/${APP_PATH}/${WORDPRESS_APP}/backup"
   fi
  print_msg "BACKUP_NAME not set will default to ${POOL_PATH}/${APP_PATH}/${WORDPRESS_APP}/backup"
  BACKUP_PATH="${POOL_PATH}/${APP_PATH}/${WORDPRESS_APP}/backup"                                                                                             
fi
if [ -z $DATABASE_NAME ]; then
  print_err 'Configuration error: BACKUP_NAME must be set'
  exit 1
fi
if [ -z $DB_BACKUP_NAME ]; then
  print_err 'Configuration error: DB_BACKUP_NAME must be set'
  exit 1
fi
if [ ! -z "$OLD_IP" ] && [ ! -z "$NEW_IP" ]; then
   MIGRATE_IP="TRUE"
   print_msg "Set to Migrate IP address from ${OLD_IP} to ${NEW_IP}"
   sed -i '' "s|OLD_IP=.*||g" ./backup-config
   sed -i '' "s|NEW_IP=.*||g" ./backup-config
   print_msg "Remove IP addresses from backup-config file as migration doesn't need to be repeated"
fi
if [ ! -z "$OLD_GATEWAY" ] && [ ! -z "$NEW_GATEWAY" ]; then
   MIGRATE_GATEWAY="TRUE"
   print_msg "Set to Migrate GATEWAY address from ${OLD_GATEWAY} to ${NEW_GATEWAY}"
   sed -i '' "s|OLD_GATEWAY=.*||g" ./backup-config
   sed -i '' "s|NEW_GATEWAY=.*||g" ./backup-config
   print_msg "Remove GATEWAY addresses from backup-config file as migration doesn't need to be repeated"
fi

# Check for the existence of the password file
if ! [ -e "/root/${WORDPRESS_APP}_db_password.txt" ]; then
   print_err "Password file not detected! DB_ROOT_PASSWORD and DB_PASSWORD must be set in backup-config."
   exit 1
else
  # Check for the existence of password variables
  . "/root/${WORDPRESS_APP}_db_password.txt"
  if [ -z "${DB_ROOT_PASSWORD}" ] || [ -z "${DB_PASSWORD}" ]; then
    print_err "The password file is corrupt."
    exit 1
  fi
fi

#
# Check if Backup dir exists
#
if [[ ! -d "${POOL_PATH}/${BACKUP_PATH}" ]]; then
   mkdir ${POOL_PATH}/${BACKUP_PATH}
   print_msg "directory "${POOL_PATH}/${BACKUP_PATH} "created"
fi

#
# Ask to Backup or restore, if cron=yes just backup
#
if [ "$cron" = "yes" ]; then
 choice="B"
else
 read -p "Enter '(B)ackup' to backup Nextcloud or '(R)estore' to restore Nextcloud: " choice
fi
echo
if [ "$choice" = "B" ] || [ "$choice" = "b" ]; then
      iocage exec ${WORDPRESS_APP} "mysqldump --single-transaction -h localhost -u "root" -p"${DB_ROOT_PASSWORD}" "${DATABASE_NAME}" > "/usr/local/www/wordpress/${DB_BACKUP_NAME}""
      print_msg "Wordpress database backup ${DB_BACKUP_NAME} complete"
      tar -czf ${POOL_PATH}/${BACKUP_PATH}/${BACKUP_NAME} -C ${POOL_PATH}/${APPS_PATH}/${WORDPRESS_APP}/${FILE_PATH} .
      print_msg "Tar file directory"
      print_msg "Backup complete file located at ${POOL_PATH}/${BACKUP_PATH}/${BACKUP_NAME}"
      echo

elif [ "$choice" = "R" ] || [ "$choice" = "r" ]; then
RESTORE_DIR=${POOL_PATH}/${APPS_PATH}/${WORDPRESS_APP}
RESTORE_SQL="/usr/local/www/wordpress"
APPS_DIR_SQL=${RESTORE_DIR}/${FILES_PATH}/${DB_BACKUP_NAME}
CONFIG_PHP="${RESTORE_DIR}/${FILES_PATH}/wp-config.php"
#echo "APPS_DIR_SQL =${APPS_DIR_SQL}"

#
# Check if currentRestoreDir exists
#
   if [ ! -d "$RESTORE_DIR" ]
   then
         print_err "ERROR: Backup ${RESTORE_DIR} not found!"
         exit 1
   fi
     print_msg "Untar ${POOL_PATH}/${BACKUP_PATH}/${BACKUP_NAME} to ${RESTORE_DIR}/${FILES_PATH}"
     tar -xzf ${POOL_PATH}/${BACKUP_PATH}/${BACKUP_NAME} -C ${RESTORE_DIR}/${FILES_PATH}
     chown -R www:www ${RESTORE_DIR}/${FILES_PATH}

if [ "${MIGRATE_IP}" == "TRUE" ]; then
     print_msg "Migrating ${DB_BACKUP_NAME} from ${OLD_IP} to ${NEW_IP}"
     sed -i '' "s/${OLD_IP}/${NEW_IP}/g" ${APPS_DIR_SQL}
     print_msg "Importing ${BACKUP_NAME} into ${DB_BACKUP_NAME}"
  if [ "${MIGRATE_GATEWAY}" != "TRUE" ]; then
     iocage exec "${WORDPRESS_APP}" "mysql -u root -p${DB_ROOT_PASSWORD} "${DATABASE_NAME}" < "${RESTORE_SQL}/${DB_BACKUP_NAME}""
  # edit wp-config.php
     print_msg "Changing ${CONFIG_PHP} password to match new install"
     WPDBPASS=`cat ${CONFIG_PHP} | grep DB_PASSWORD | cut -d \' -f 4`
     sed -i '' "s|${WPDBPASS}|${DB_PASSWORD}|" ${CONFIG_PHP}
  fi
fi
if [ "${MIGRATE_GATEWAY}" == "TRUE" ]; then
     print_msg "Migrating ${DB_BACKUP_NAME} from ${OLD_GATEWAY} to ${NEW_GATEWAY}"
     sed -i '' "s/${OLD_GATEWAY}/${NEW_GATEWAY}/g" ${APPS_DIR_SQL}
     print_msg "Importing ${BACKUP_NAME} into ${DB_BACKUP_NAME}"
     iocage exec "${WORDPRESS_APP}" "mysql -u root -p${DB_ROOT_PASSWORD} "${DATABASE_NAME}" < "${RESTORE_SQL}/${DB_BACKUP_NAME}""
  # edit wp-config.php
     print_msg "Changing ${CONFIG_PHP} password to match new install"
     WPDBPASS=`cat ${CONFIG_PHP} | grep DB_PASSWORD | cut -d \' -f 4`
     sed -i '' "s|${WPDBPASS}|${DB_PASSWORD}|" ${CONFIG_PHP}
fi

if [ "${MIGRATE_IP}" != "TRUE" ] && [ "${MIGRATE_GATEWAY}" != "TRUE" ]; then

   print_msg "Restore Database No Migration"
   iocage exec ${WORDPRESS_APP} "mysql -u "root" -p"${DB_ROOT_PASSWORD}" "${DATABASE_NAME}" < "${RESTORE_SQL}/${DB_BACKUP_NAME}""
   print_msg "The database ${DB_BACKUP_NAME} has been restored restarting"
fi
   iocage restart ${WORDPRESS_APP}
   echo
else
  print_err "Must enter '(B)ackup' to backup Wordpress or '(R)estore' to restore app directory: "
  echo
fi

