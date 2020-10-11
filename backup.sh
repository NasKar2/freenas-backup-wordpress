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

APPS_PATH=""
BACKUP_PATH=""
FILES_PATH=""
BACKUP_NAME=""
JAIL_NAME=""
DATABASE_NAME=""
DB_BACKUP_NAME=""
JAIL_FILES_LOC=""
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
if [ -z $JAIL_NAME ]; then
  JAIL_NAME="wordpress"
  print_msg "JAIL_NAME not set will default to 'wordpress'"
fi
if [ -z $APPS_PATH ]; then
  APPS_PATH="apps"
  print_msg "APPS_PATH defaulting to 'apps'"
fi
if [ -z $FILES_PATH ]; then
  print_msg "FILES_PATH not set will default to 'files'"
  FILES_PATH="files"
fi
if [ -z $DATABASE_NAME ]; then
  DATABASE_NAME="wordpress"
  print_msg "DATABASE_NAME not set will default to wordpress"
fi
if [ -z $DB_BACKUP_NAME ]; then
  DB_BACKUP_NAME="wordpress.sql"
  print_msg "DB_BACKUP_NAME not set will default to wordpress.sql"
fi
if [ -z $JAIL_FILES_LOC ]; then
  JAIL_FILES_LOC="/usr/local/www/wordpress"
  print_msg "JAIL_FILES_LOC not set will default to '/usr/loca/www/wordpress'"
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

#
# Check if JAIL PASSWORD files exist for each jail in $JAIL_NAME
#
DATE=$(date +'_%F_%H%M')
array=(${JAIL_NAME})
#echo "There are ${#array[@]} jails"

for dir in "${array[@]}"; do echo; done

#for dir in */; do echo; done

for JAIL in "${array[@]}"
do
#echo $JAIL
BACKUP_NAME="${JAIL}${DATE}"
#echo $BACKUP_NAME

# Check for the existence of the password file.

# Reset PASSWORDS
DB_ROOT_PASSWORD=""
DB_PASSWORD=""
if ! [ -e "/root/${JAIL}_db_password.txt" ]; then
   # It doesn't exist. Have the passwords been supplied in backup-config?
   print_err "You must have a file ${JAIL}_db_password.txt containing DB_ROOT_PASSWORD and DB_PASSWORD"
   exit 1
else
   # It does exist. Check for the existence of password variables in the password file.
   . "/root/${JAIL}_db_password.txt"
   if [ -z "${DB_ROOT_PASSWORD}" ] || [ -z "${DB_PASSWORD}" ]; then
      print_err "The password file is corrupt."
      exit 1
   fi
fi

if [ -z $BACKUP_PATH ]; then
  BACKUP_PATH="backup"
  print_msg="BACUP_PATH is ${BACKUP_PATH}"
   if [ ! -d "${POOL_PATH}/${BACKUP_PATH}/${JAIL}" ]
    then
#      echo "mkdir in backup_path"
#      BACKUP_PATH="backup/${JAIL}"
       mkdir -p "${POOL_PATH}/${BACKUP_PATH}/${JAIL}"
       print_msg "BACKUP_PATH not set will default to ${POOL_PATH}/${BACKUP_PATH}/${JAIL}"
    fi
fi   
#
# Check if Backup dir exists
#
if [[ ! -d "${POOL_PATH}/backup/${JAIL}" ]]; then
#  echo "mkdir in check if backup dir exists"
   mkdir ${POOL_PATH}/backup/${JAIL}
   print_msg "Directory "${POOL_PATH}/backup/${JAIL} "created"
else
   print_msg "Backup location ${POOL_PATH}/backup/${JAIL} already exists"
fi

#echo "ROOT PASSWORD is $DB_ROOT_PASSWORD"
#echo "PASSWORD is $DB_PASSWORD"
echo
done
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
# LOOP BACKUP #
array=(${JAIL_NAME})
print_msg "There are ${#array[@]} jails ${JAIL_NAME}"
 
#for dir in "${array[@]}"; do echo; done
  
#for dir in */; do echo; done

for JAIL in "${array[@]}"
do
echo "*********************************************************************"
BACKUP_NAME="${JAIL}${DATE}.tar.gz"
print_msg "Backing up ${JAIL} to ${BACKUP_NAME}"

# Read the password file.
      
# Reset PASSWORDS
DB_ROOT_PASSWORD=""
DB_PASSWORD=""
   . "/root/${JAIL}_db_password.txt"

#echo "ROOT PASSWORD is $DB_ROOT_PASSWORD"
#echo "PASSWORD is $DB_PASSWORD"
echo
      iocage exec ${JAIL} "mysqldump --single-transaction -h localhost -u "root" -p"${DB_ROOT_PASSWORD}" "${DATABASE_NAME}" > "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
      print_msg "Wordpress database backup ${DB_BACKUP_NAME} complete"
echo "tar -czf ${POOL_PATH}/backup/${JAIL}/${BACKUP_NAME} -C ${POOL_PATH}/${APPS_PATH}/${JAIL}/${FILES_PATH} ."
      tar -czf ${POOL_PATH}/backup/${JAIL}/${BACKUP_NAME} -C ${POOL_PATH}/${APPS_PATH}/${JAIL}/${FILES_PATH} .

#tar -cvzf /mnt/v1/git/freenas-backup-wordpress/wordpress.tar.gz -C /mnt/v1/apps/wordpress/files/ . -C /root/ ./wordpress_db_password.txt
#tar -C /mnt/v1/git/freenas-backup-wordpress/files -zxvf /mnt/v1/git/freenas-backup-wordpress/wordpress.tar.gz
      print_msg "Backup complete file located at ${POOL_PATH}/${BACKUP_PATH}/${BACKUP_NAME}"

#
# Delete old backups
#
   if [ $MAX_NUM_BACKUPS -ne 0 ]
     then
      print_msg "Maximum number of backups is $MAX_NUM_BACKUPS"
#        echo "MAX_NUM_BACKUPS is not 0"
         shopt -s nullglob
         BACKUP_FILES=( "${POOL_PATH}/${BACKUP_PATH}/${JAIL}/${JAIL}"*.tar.gz )
         NUM_BACKUPS=${#BACKUP_FILES[@]}
#        NUM_BACKUPS="$(ls -l ${POOL_PATH}/backup/${JAIL} | grep -c "${JAIL}.*.tar.gz$")"
#        echo "NUM_BACKUPS=" $NUM_BACKUPS
         NUM_FILES_REMOVE="$((NUM_BACKUPS - MAX_NUM_BACKUPS))"

#        echo "NUM_FILES_REMOVE=" $NUM_FILES_REMOVE

           while [ $NUM_FILES_REMOVE -gt 0 ]
           do
#            echo "number Files to remove=" $NUM_FILES_REMOVE
             FILE_TO_REMOVE=${BACKUP_FILES[0]}
             print_msg "Removing Files ${FILE_TO_REMOVE}"
             NUM_FILES_REMOVE="$((NUM_FILES_REMOVE - 1))"
             rm ${FILE_TO_REMOVE}
           done
   fi

echo
print_msg "DONE!"

done

elif [ "$choice" = "R" ] || [ "$choice" = "r" ]; then

# LOOP Restore #

array=(${JAIL_NAME})
#for JAIL in "${array[@]}"; do echo; done

#for JAIL in */; do echo; done

if [[ "${#array[@]}" > "1" ]]; then
echo "There are ${#array[@]} jails available to restore, pick the one to restore"; \
select JAIL in "${array[@]}"; do echo; break; done
print_msg "You choose the jail '${JAIL}' to restore"
fi

RESTORE_DIR=${POOL_PATH}/${APPS_PATH}/${JAIL}
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
         mkdir -p $RESTORE_DIR
         print_msg "Create directory ${RESTORE_DIR}"
   fi

#
# Pick the restore directory *don't edit this section*
#
cd "${POOL_PATH}/backup/${JAIL}"
shopt -s dotglob
shopt -s nullglob
array=(${JAIL}*.tar.gz)
for dir in "${array[@]}"; do echo; done

for dir in */; do echo; done

echo "There are ${#array[@]} backups available, pick the one to restore"; \
select dir in "${array[@]}"; do echo; break; done

print_msg "You choose ${dir}"
BACKUP_NAME=$dir
     print_msg "Untar ${POOL_PATH}/${BACKUP_PATH}/${JAIL}/${BACKUP_NAME} to ${RESTORE_DIR}/${FILES_PATH}"
     tar -xzf ${POOL_PATH}/${BACKUP_PATH}/${JAIL}/${BACKUP_NAME} -C ${RESTORE_DIR}/${FILES_PATH}
#    mv ${RESTORE_DIR}/${FILES_PATH}/"${JAIL}_db_password.txt" /root/"${JAIL}_db_password.txt" 
    chown -R www:www ${RESTORE_DIR}/${FILES_PATH}

if [ "${MIGRATE_IP}" == "TRUE" ]; then
     print_msg "Migrating ${DB_BACKUP_NAME} from ${OLD_IP} to ${NEW_IP}"
     sed -i '' "s/${OLD_IP}/${NEW_IP}/g" ${APPS_DIR_SQL}
     print_msg "Importing ${BACKUP_NAME} into ${DB_BACKUP_NAME}"
  if [ "${MIGRATE_GATEWAY}" != "TRUE" ]; then
     iocage exec "${JAIL}" "mysql -u root -p${DB_ROOT_PASSWORD} "${DATABASE_NAME}" < "${RESTORE_SQL}/${DB_BACKUP_NAME}""
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
     iocage exec "${JAIL}" "mysql -u root -p${DB_ROOT_PASSWORD} "${DATABASE_NAME}" < "${RESTORE_SQL}/${DB_BACKUP_NAME}""
  # edit wp-config.php
     print_msg "Changing ${CONFIG_PHP} password to match new install"
     WPDBPASS=`cat ${CONFIG_PHP} | grep DB_PASSWORD | cut -d \' -f 4`
     sed -i '' "s|${WPDBPASS}|${DB_PASSWORD}|" ${CONFIG_PHP}
fi

if [ "${MIGRATE_IP}" != "TRUE" ] && [ "${MIGRATE_GATEWAY}" != "TRUE" ]; then

   print_msg "Restore Database No Migration"
   iocage exec ${JAIL} "mysql -u "root" -p"${DB_ROOT_PASSWORD}" "${DATABASE_NAME}" < "${RESTORE_SQL}/${DB_BACKUP_NAME}""
   print_msg "The database ${DB_BACKUP_NAME} has been restored restarting"
fi
   iocage restart ${JAIL}
   echo
else
  print_err "Must enter '(B)ackup' to backup Wordpress or '(R)estore' to restore app directory: "
  echo
fi

