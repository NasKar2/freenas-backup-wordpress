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

POOL_PATH=""
APPS_PATH=""
BACKUP_PATH=""
FILES_PATH=""
BACKUP_NAME=""
JAIL_NAME=""
DATABASE_NAME=""
DB_BACKUP_NAME=""
IP_OLD=""
IP_NEW=""
OLD_GATEWAY=""
NEW_GATEWAY=""
DB_ROOT_PASSWORD=""
DB_PASSWORD=""
MAX_NUM_BACKUPS="2"

#if ! [ -e "backup-config" ]; then 
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/backup-config
#fi
#
# Check if backup-config created correctly
#

if [ -z $POOL_PATH ]; then
  POOL_PATH="/mnt/$(iocage get -p)"
  print_msg "POOL_PATH defaulting to "$POOL_PATH
fi
if [ -z $APPS_PATH ]; then
  APPS_PATH="apps"
  print_msg "APPS_PATH defaulting to 'apps'"
fi
if [ -z $FILES_PATH ]; then
  print_msg "FILES_PATH not set will default to 'files'"
  FILES_PATH="files"
fi
if [ -z $JAIL_NAME ]; then
  print_msg "JAIL_NAME not set so will be set to default 'wordpress'"
  JAIL_NAME="wordpress"
fi
if [ -z $BACKUP_NAME ]; then
  BACKUP_NAME="${JAIL_NAME}$(date +'_%F_%H%M').tar.gz"
  print_msg "BACKUP_NAME not set will default to ${JAIL_NAME}$(date +'_%F_%H%M').tar.gz"                                                 
fi
if [ -z $BACKUP_PATH ]; then
   if [ ! -d "${POOL_PATH}/backup/${JAIL_NAME}" ]
    then
#      echo "mkdir in backup_path"   
      mkdir -p "${POOL_PATH}/backup/${JAIL_NAME}"
   fi
  BACKUP_PATH="backup/${JAIL_NAME}"
  print_msg "BACKUP_PATH not set will default to ${POOL_PATH}/backup/${JAIL_NAME}"                                                                                             
fi
if [ -z $DATABASE_NAME ]; then
  DATABASE_NAME="wordpress"
  print_msg "DATABASE_NAME not set will default to wordpress"
fi
if [ -z $DB_BACKUP_NAME ]; then
  DB_BACKUP_NAME="wordpress.sql"
  print_msg "DB_BACKUP_NAME not set will default to wordpress.sql"
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

# Check for the existence of the password file.
if ! [ -e "/root/${JAIL_NAME}_db_password.txt" ]; then
   # It doesn't exist. Have the passwords been supplied in backup-config?
   if [ -z "${DB_ROOT_PASSWORD}" ] || [ -z "${DB_PASSWORD}" ]; then
      print_err "Password file not detected! DB_ROOT_PASSWORD and DB_PASSWORD must be set in backup-config."
      exit 1
   fi   
else
   # It does exist. Check for the existence of password variables in the password file.
   . "/root/${JAIL_NAME}_db_password.txt"
   if [ -z "${DB_ROOT_PASSWORD}" ] || [ -z "${DB_PASSWORD}" ]; then
      print_err "The password file is corrupt."
      exit 1
   fi
 fi

#
# Check if Backup dir exists
#
if [[ ! -d "${POOL_PATH}/${BACKUP_PATH}" ]]; then
   echo "mkdir in check if backup dir exists" 
   mkdir ${POOL_PATH}/${BACKUP_PATH}
   print_msg "directory "${POOL_PATH}/${BACKUP_PATH} "created"
fi
#echo $POOL_PATH
#echo $APPS_PATH
#echo $BACKUP_NAME
#
# Ask to Backup or restore, if run interactively
#
if ! [ -t 1 ] ; then
  # Not run interactively
  choice="B"
else
 read -p "Enter '(B)ackup' to backup Nextcloud or '(R)estore' to restore Nextcloud: " choice
fi
echo
if [ "$choice" = "B" ] || [ "$choice" = "b" ]; then
      iocage exec ${JAIL_NAME} "mysqldump --single-transaction -h localhost -u "root" -p"${DB_ROOT_PASSWORD}" "${DATABASE_NAME}" > "/usr/local/www/wordpress/${DB_BACKUP_NAME}""
      print_msg "Wordpress database backup ${DB_BACKUP_NAME} complete"
      tar -czf ${POOL_PATH}/${BACKUP_PATH}/${BACKUP_NAME} -C ${POOL_PATH}/${APPS_PATH}/${JAIL_NAME}/${FILE_PATH} .

#tar -cvzf /mnt/v1/git/freenas-backup-wordpress/wordpress.tar.gz -C /mnt/v1/apps/wordpress/files/ . -C /root/ ./wordpress_db_password.txt
#tar -C /mnt/v1/git/freenas-backup-wordpress/files -zxvf /mnt/v1/git/freenas-backup-wordpress/wordpress.tar.gz

      print_msg "Tar file directory"
      print_msg "Backup complete file located at ${POOL_PATH}/${BACKUP_PATH}/${BACKUP_NAME}"
      echo "***********************************"

#
# Delete old backups
#
if [ $MAX_NUM_BACKUPS -ne 0 ]
then
      print_msg "Maximum number of backups is $MAX_NUM_BACKUPS"
#     echo "MAX_NUM_BACKUPS is not 0"
        NUM_BACKUPS="$(ls -l ${POOL_PATH}/${BACKUP_PATH} | grep -c '\wordpress.*.tar.gz$')"
#     echo "NUM_BACKUPS=" $NUM_BACKUPS
        NUM_FILES_REMOVE="$((NUM_BACKUPS - MAX_NUM_BACKUPS))"

#     echo "NUM_FILES_REMOVE=" $NUM_FILES_REMOVE

while [ $NUM_FILES_REMOVE -gt 0 ]
do
#echo
#echo "number Files to remove=" $NUM_FILES_REMOVE
FILE_TO_REMOVE="$(ls -t ${POOL_PATH}/${BACKUP_PATH} | tail -1)"
print_msg "Removing Files ${FILE_TO_REMOVE}"
NUM_FILES_REMOVE="$((NUM_FILES_REMOVE - 1))"
rm ${POOL_PATH}/${BACKUP_PATH}/${FILE_TO_REMOVE}
done
fi

echo
print_msg "DONE!"


elif [ "$choice" = "R" ] || [ "$choice" = "r" ]; then
RESTORE_DIR=${POOL_PATH}/${APPS_PATH}/${JAIL_NAME}
RESTORE_SQL="/usr/local/www/wordpress"
APPS_DIR_SQL=${RESTORE_DIR}/${FILES_PATH}/${DB_BACKUP_NAME}
CONFIG_PHP="${RESTORE_DIR}/${FILES_PATH}/wp-config.php"
backupMainDir="${POOL_PATH}/${BACKUP_PATH}"
#echo "APPS_DIR_SQL =${APPS_DIR_SQL}"

#
# Check if currentRestoreDir exists
#
   if [ ! -d "$RESTORE_DIR" ]
   then
         print_err "ERROR: Backup ${RESTORE_DIR} not found!"
         exit 1
   fi

#
# Pick the restore directory *don't edit this section*
#
cd "${POOL_PATH}/${BACKUP_PATH}"
shopt -s dotglob
shopt -s nullglob
array=(${JAIL_NAME}*.tar.gz)
for dir in "${array[@]}"; do echo; done

for dir in */; do echo; done

echo "There are ${#array[@]} backups available, pick the one to restore"; \
select dir in "${array[@]}"; do echo; break; done

echo "You choose ${dir}"
BACKUP_NAME=$dir
     print_msg "Untar ${POOL_PATH}/${BACKUP_PATH}/${BACKUP_NAME} to ${RESTORE_DIR}/${FILES_PATH}"
     tar -xzf ${POOL_PATH}/${BACKUP_PATH}/${BACKUP_NAME} -C ${RESTORE_DIR}/${FILES_PATH}
#    mv ${RESTORE_DIR}/${FILES_PATH}/"${JAIL_NAME}_db_password.txt" /root/"${JAIL_NAME}_db_password.txt" 
    chown -R www:www ${RESTORE_DIR}/${FILES_PATH}

if [ "${MIGRATE_IP}" == "TRUE" ]; then
     print_msg "Migrating ${DB_BACKUP_NAME} from ${OLD_IP} to ${NEW_IP}"
     sed -i '' "s/${OLD_IP}/${NEW_IP}/g" ${APPS_DIR_SQL}
     print_msg "Importing ${BACKUP_NAME} into ${DB_BACKUP_NAME}"
  if [ "${MIGRATE_GATEWAY}" != "TRUE" ]; then
     iocage exec "${JAIL_NAME}" "mysql -u root -p${DB_ROOT_PASSWORD} "${DATABASE_NAME}" < "${RESTORE_SQL}/${DB_BACKUP_NAME}""
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
     iocage exec "${JAIL_NAME}" "mysql -u root -p${DB_ROOT_PASSWORD} "${DATABASE_NAME}" < "${RESTORE_SQL}/${DB_BACKUP_NAME}""
  # edit wp-config.php
     print_msg "Changing ${CONFIG_PHP} password to match new install"
     WPDBPASS=`cat ${CONFIG_PHP} | grep DB_PASSWORD | cut -d \' -f 4`
     sed -i '' "s|${WPDBPASS}|${DB_PASSWORD}|" ${CONFIG_PHP}
fi

if [ "${MIGRATE_IP}" != "TRUE" ] && [ "${MIGRATE_GATEWAY}" != "TRUE" ]; then

   print_msg "Restore Database No Migration"
   iocage exec ${JAIL_NAME} "mysql -u "root" -p"${DB_ROOT_PASSWORD}" "${DATABASE_NAME}" < "${RESTORE_SQL}/${DB_BACKUP_NAME}""
   print_msg "The database ${DB_BACKUP_NAME} has been restored restarting"
fi
   iocage restart ${JAIL_NAME}
   echo
else
  print_err "Must enter '(B)ackup' to backup Wordpress or '(R)estore' to restore app directory: "
  echo
fi

