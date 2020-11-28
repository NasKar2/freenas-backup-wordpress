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


phar_install () {
PHP_VER=$(iocage exec ${JAIL} php -v | grep ^PHP | cut -d ' ' -f2 | cut -d '.' -f-2)
PHP_VER=${PHP_VER//.}
PHP_PHAR=php${PHP_VER}-phar
PKG_INFO=$(iocage exec ${JAIL} pkg info | grep ${PHP_PHAR} | grep ^${PHP_PHAR} | cut -d '-' -f2)
if [[ $PKG_INFO != "phar" ]]; then
   print_msg "php74-phar does not exist, will install"
   iocage exec ${JAIL} "pkg install -y $PHP_PHAR"
fi
   if [ ! -e "${POOL_PATH}/iocage/jails/${JAIL}/root/usr/local/bin/wp" ]; then
      print_msg  "wp-cli.phar does not exist, will install and move to /usr/local/bin/wp"
      iocage exec ${JAIL} "cd ${JAIL_FILES_LOC} && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
      iocage exec ${JAIL} "cd ${JAIL_FILES_LOC} && chmod +x wp-cli.phar"
      iocage exec ${JAIL} "cd ${JAIL_FILES_LOC} && mv wp-cli.phar /usr/local/bin/wp"
    fi

}

maintenance_activate () {
iocage exec ${JAIL} " wp --path="${JAIL_FILES_LOC}" maintenance-mode activate"
}

maintenance_deactivate () {
iocage exec ${JAIL} " wp --path="${JAIL_FILES_LOC}" maintenance-mode deactivate"
}


# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   print_err "This script must be run with root privileges"
   exit 1
fi

#
# Initialize Variables
#

JAIL_NAME=""
BACKUP_PATH=""
APPS_PATH=""
FILES_PATH=""
DATABASE_NAME=""
JAIL_FILES_LOC=""
OLD_IP=""
NEW_IP=""
OLD_GATEWAY=""
NEW_GATEWAY=""
MAX_NUM_BACKUPS=""

# Check if backup-config exists and read the file
if [ -e "backup-config" ]; then 
  SCRIPT=$(readlink -f "$0")
  SCRIPTPATH=$(dirname "$SCRIPT")
  . $SCRIPTPATH/backup-config
  print_msg "backup-config exists will read it"
else
  print_msg "backup-config does not exist will use defaults"
fi

# Check if backup-config created correctly or set defaults
if [ -z $POOL_PATH ]; then
  POOL_PATH="/mnt/$(iocage get -p)"
  print_msg "POOL_PATH defaulting to "$POOL_PATH
fi
if [[ -z "$JAIL_NAME" ]] && [[ $# = 0 ]]; then
  JAIL_NAME="wordpress"
  print_msg "JAIL_NAME not set will default to 'wordpress'"
fi
if [ -z $APPS_PATH ]; then
  APPS_PATH="apps"
  print_msg "APPS_PATH defaulting to 'apps'"
fi
if [ -z $BACKUP_PATH ]; then
  BACKUP_PATH="backup"
  print_msg "BACKUP_PATH is ${BACKUP_PATH}"
fi
if [ -z $FILES_PATH ]; then
  print_msg "FILES_PATH not set will default to 'files'"
  FILES_PATH="files"
fi
if [ -z $DATABASE_NAME ]; then
  DATABASE_NAME="wordpress"
  print_msg "DATABASE_NAME not set will default to wordpress"
fi

DB_BACKUP_NAME="wordpress.sql"
print_msg "DB_BACKUP_NAME set to 'wordpress.sql'"

if [ -z $JAIL_FILES_LOC ]; then
  JAIL_FILES_LOC="/usr/local/www/wordpress"
  print_msg "JAIL_FILES_LOC not set will default to '/usr/local/www/wordpress'"
fi

if [ -z $MAX_NUM_BACKUPS ]; then                                                      
  MAX_NUM_BACKUPS=0
  print_msg "MAX_NUM_BACKUPS not set will default to '0' unlimited"
fi

if [ ! -z "$OLD_IP" ] && [ ! -z "$NEW_IP" ]; then
   MIGRATE_IP="TRUE"
   print_msg "Set to Migrate IP address from ${OLD_IP} to ${NEW_IP}"
   sed -i '' "s|OLD_IP=.*||g" ./backup-config
   sed -i '' "s|NEW_IP=.*||g" ./backup-config
   sed -i '' "s|OLD_GATEWAY=.*||g" ./backup-config
   sed -i '' "s|NEW_GATEWAY=.*||g" ./backup-config
   print_msg "Remove IP addresses from backup-config file as migration doesn't need to be repeated"
fi
if [ ! -z "$OLD_GATEWAY" ] && [ ! -z "$NEW_GATEWAY" ]; then
   MIGRATE_GATEWAY="TRUE"
   print_msg "Set to Migrate GATEWAY address from ${OLD_GATEWAY} to ${NEW_GATEWAY}"             
#   sed -i '' "s|OLD_GATEWAY=.*||g" ./backup-config
#   sed -i '' "s|NEW_GATEWAY=.*||g" ./backup-config
   print_msg "Remove GATEWAY addresses from backup-config file as migration doesn't need to be repeated"
fi


# Check if argument set
if [[ $# = 0 ]]; then
   array=($JAIL_NAME)
   print_msg "There are ${#array[@]} jails ${JAIL_NAME}"
else
   unset array
for i in $@
  do
   array+=($i)
  done
#   echo "There were $# arguments"
#   for dir in "${array[@]}"; do echo $dir; done
fi
for JAIL in "${array[@]}"; do echo; done

# Check if JAIL PASSWORD files and BACKUP_PATH exist for each jail in $JAIL_NAME
DATE=$(date +'_%F_%H%M')
i=0
for JAIL in "${array[@]}"
do
# Check if ${POOL_PATH}/${APPS_PATH}/${JAIL} exists
   if [[ ! -d "${POOL_PATH}/${APPS_PATH}/${JAIL}" ]]; then
         print_err "********* ${POOL_PATH}/${APPS_PATH}/${JAIL} does not exist. There must not be a wordpress install in that data directory."
         exit 1
   fi
# Check if "/root/${JAIL}_db_password.txt" exists
   if [[ ! -e "/root/${JAIL}_db_password.txt" ]]; then
        print_err "The password file '/root/${JAIL}_db_password.txt' does not exist"
        exit 1
   fi
# Check for the existence of the password file
# Reset PASSWORDS
DB_ROOT_PASSWORD=""
DB_PASSWORD=""

DB_VERSION="$(iocage exec ${JAIL} "mysql -V | cut -d ' ' -f 6  | cut -d . -f -2")"
DB_VERSION="${DB_VERSION//.}"
version[i]=$DB_VERSION
#echo "version is $version[$i]"
i=$((i+1))
#print_err "Database Version is "${DB_VERSION}
if ! [ -e "/root/${JAIL}_db_password.txt" ]; then
   # It doesn't exist. Have the passwords been supplied in backup-config?
  if (( $DB_VERSION >= 104 )); then
   print_err "You must have a file ${JAIL}_db_password.txt that contains only the variable DB_PASSWORD"
   exit 1
  else
   print_err "You must have a file ${JAIL}_db_password.txt that containing the variables DB_ROOT_PASSWORD and DB_PASSWORD"
   exit 1
  fi
else
   # It does exist. Check for the existence of password variables in the password file.
   . "/root/${JAIL}_db_password.txt"
  if (( $DB_VERSION >= 104 )); then
   if [ -z "${DB_PASSWORD}" ]; then
      print_err "The password file is corrupt."
   fi
  else
   if [ -z "${DB_ROOT_PASSWORD}" ] || [ -z "${DB_PASSWORD}" ]; then
      print_err "The password file is corrupt."
      exit 1
   fi
  fi
fi
# Check if Backup dir exists
if [[ -d "${POOL_PATH}/${BACKUP_PATH}/${JAIL}" ]]; then
   print_msg "Backup location ${POOL_PATH}/${BACKUP_PATH}/${JAIL} already exists"
else
#   echo "mkdir in check if backup dir exists"
   mkdir -p ${POOL_PATH}/${BACKUP_PATH}/${JAIL}
   print_msg "Creating Directory ${POOL_PATH}/${BACKUP_PATH}/${JAIL}"
fi

echo
done
#for dir in "${version[@]}"; do echo $dir; done
# Ask to Backup or restore, if run interactively
if ! [ -t 1 ] ; then
  # Not run interactively
  choice="B"
else
 read -p "Enter '(B)ackup' to backup Nextcloud or '(R)estore' to restore Nextcloud: " choice
fi
echo
if [ "$choice" = "B" ] || [ "$choice" = "b" ]; then
# LOOP BACKUP #
for i in "${!array[@]}"; do
#echo $i
JAIL=${array[$i]}
#print_err "${JAIL}"
echo "*********************************************************************"
BACKUP_NAME="${JAIL}${DATE}.tar.gz"
print_msg "Backing up ${JAIL} to ${BACKUP_NAME}"
# Check if ${POOL_PATH}/${APPS_PATH}/${JAIL} exists
   if [ ! -d "${POOL_PATH}/${APPS_PATH}/${JAIL}" ]
   then
#         mkdir -p $RESTORE_DIR
         print_err "${POOL_PATH}/${APPS_PATH}/${JAIL} does not exist. You are trying to backup a data directory that doesn't exist."
         exit 1
#         print_msg "Create directory ${RESTORE_DIR}"
   fi

# Read the password file.
# Reset PASSWORDS
DB_ROOT_PASSWORD=""
DB_PASSWORD=""
#   . "/root/${JAIL}_db_password.txt"
DB_PASSWORD=`cat /root/${JAIL}_db_password.txt | grep DB_PASSWORD | cut -d '"' -f2`
DB_ROOT_PASSWORD=`cat /root/${JAIL}_db_password.txt | grep DB_ROOT_PASSWORD | cut -d '"' -f2`
DB_VERSION=${version[$i]}
#print_err "Current DB_VERSION is "${DB_VERSION}
echo
##################################################
phar_install
maintenance_activate
  if (( $DB_VERSION >= 104 )); then
      iocage exec ${JAIL} "mysqldump --single-transaction -h localhost -u "root" "${DATABASE_NAME}" > "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
  else
      iocage exec ${JAIL} "mysqldump --single-transaction -h localhost -u "root" -p"${DB_ROOT_PASSWORD}" "${DATABASE_NAME}" > "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
  fi  
    print_msg "${JAIL} database backup ${DB_BACKUP_NAME} complete"
if [[ "${FILES_PATH}" = "/" ]]; then
#      echo "tar -czf ${POOL_PATH}/backup/${JAIL}/${BACKUP_NAME} -C ${POOL_PATH}/${APPS_PATH}/${JAIL} ."
      tar -czf ${POOL_PATH}/backup/${JAIL}/${BACKUP_NAME} -C ${POOL_PATH}/${APPS_PATH}/${JAIL} .
else
#      echo "tar -czf ${POOL_PATH}/backup/${JAIL}/${BACKUP_NAME} -C ${POOL_PATH}/${APPS_PATH}/${JAIL}/${FILES_PATH} ."
      tar -czf ${POOL_PATH}/backup/${JAIL}/${BACKUP_NAME} -C ${POOL_PATH}/${APPS_PATH}/${JAIL}/${FILES_PATH} .

fi
      print_msg "${JAIL} files backup complete"
      print_msg "Backup complete file located at ${POOL_PATH}/${BACKUP_PATH}/${JAIL}/${BACKUP_NAME}"
maintenance_deactivate

# Delete old backups
   if [ $MAX_NUM_BACKUPS -ne 0 ]
     then
      print_msg "Maximum number of backups is $MAX_NUM_BACKUPS"
         shopt -s nullglob
         BACKUP_FILES=( "${POOL_PATH}/${BACKUP_PATH}/${JAIL}/${JAIL}_"*.tar.gz )
         NUM_BACKUPS=${#BACKUP_FILES[@]}
         NUM_FILES_REMOVE="$((NUM_BACKUPS - MAX_NUM_BACKUPS))"

        NUM=0
           while [ $NUM_FILES_REMOVE -gt 0 ]
           do
             FILE_TO_REMOVE=${BACKUP_FILES[${NUM}]}
             print_msg "Removing Files ${FILE_TO_REMOVE}"
             NUM_FILES_REMOVE="$((NUM_FILES_REMOVE - 1))"
             NUM=$((NUM+1))
             rm $FILE_TO_REMOVE
           done
         shopt -u nullglob  
   fi

echo
print_msg "DONE!"

done

elif [ "$choice" = "R" ] || [ "$choice" = "r" ]; then

# LOOP Restore #
if [[ $# = 0 ]]; then
   array=($JAIL_NAME)
else
   unset array
for i in $@
  do
   array+=($i)
  done
fi

for JAIL in "${array[@]}"; do echo; done

if [[ "${#array[@]}" > "1" ]]; then
echo "There are ${#array[@]} jails available to restore, pick the one to restore"; \
select JAIL in "${array[@]}"; do echo; break; done
print_msg "You choose the jail '${JAIL}' to restore"
fi
DB_VERSION="$(iocage exec ${JAIL} "mysql -V | cut -d ' ' -f 6  | cut -d . -f -2")"
DB_VERSION="${DB_VERSION//.}"

# Read the password file.
# Reset PASSWORDS
DB_ROOT_PASSWORD=""
DB_PASSWORD=""
#   . "/root/${JAIL}_db_password.txt"
DB_PASSWORD=`cat /root/${JAIL}_db_password.txt | grep DB_PASSWORD | cut -d '"' -f2`
DB_ROOT_PASSWORD=`cat /root/${JAIL}_db_password.txt | grep DB_ROOT_PASSWORD | cut -d '"' -f2`
RESTORE_DIR=${POOL_PATH}/${APPS_PATH}/${JAIL}
if [[ "${FILES_PATH}" = "/" ]]; then
   APPS_DIR_SQL=${RESTORE_DIR}/${DB_BACKUP_NAME}
   CONFIG_PHP="${RESTORE_DIR}/wp-config.php"
else
   APPS_DIR_SQL=${RESTORE_DIR}/${FILES_PATH}/${DB_BACKUP_NAME}
   CONFIG_PHP="${RESTORE_DIR}/${FILES_PATH}/wp-config.php"
fi
backupMainDir="${POOL_PATH}/${BACKUP_PATH}"
echo "RESTORE_DIR is ${RESTORE_DIR}"
echo "APPS_DIR_SQL is ${APPS_DIR_SQL}"
echo "CONFIG_PHP is ${CONFIG_PHP}"
# Check if RESTORE_DIR exists
   if [ ! -d "$RESTORE_DIR" ]
   then
#         mkdir -p $RESTORE_DIR
         print_err "$RESTORE_DIR does not exist. You must set the JAIL_NAME variable in the config to name of the wordpress DATA directory"
         print_err "This will be in the ${POOL_PATH}/${APPS_PATH} directory"
         exit 1
#         print_msg "Create directory ${RESTORE_DIR}"
   fi

# Pick the restore file *don't edit this section*
cd "${POOL_PATH}/${BACKUP_PATH}/${JAIL}"
shopt -s  nullglob
array=(${JAIL}*.tar.gz)
for dir in "${array[@]}"; do echo; done

for dir in */; do echo; done

if [ ${#array[@]} = 0 ]; then
print_err "There are ${#array[@]} .tar.gz files in the backup directory"
exit 1
else
echo "There are ${#array[@]} backups available, pick the one to restore"; \
fi

select dir in "${array[@]}"; do echo; break; done
while [[ ! $REPLY -le ${#array[@]} ]] || [[ ! "$REPLY" =~ ^[0-9]+$ ]] || [[ ! "$REPLY" -ne 0 ]];
do
if [[ ! $REPLY -le ${#array[@]} ]] || [[ ! "$REPLY" =~ ^[0-9]+$ ]] || [[ ! "$REPLY" -ne 0 ]]; then
  #clear
  print_err "$REPLY is invalid try again"
fi
select dir in "${array[@]}"; do echo; break; done
done
print_msg "You choose ${dir}"
shopt -u nullglob
phar_install
maintenance_activate
BACKUP_NAME=$dir
if [[ "${FILES_PATH}" = "/" ]]; then
     print_msg "Untar ${POOL_PATH}/${BACKUP_PATH}/${JAIL}/${BACKUP_NAME} to ${RESTORE_DIR}"
     tar -xzf ${POOL_PATH}/${BACKUP_PATH}/${JAIL}/${BACKUP_NAME} -C ${RESTORE_DIR}
    chown -R www:www ${RESTORE_DIR}
else
     print_msg "Untar ${POOL_PATH}/${BACKUP_PATH}/${JAIL}/${BACKUP_NAME} to ${RESTORE_DIR}/${FILES_PATH}"
     tar -xzf ${POOL_PATH}/${BACKUP_PATH}/${JAIL}/${BACKUP_NAME} -C ${RESTORE_DIR}/${FILES_PATH}
    chown -R www:www ${RESTORE_DIR}/${FILES_PATH}
fi
if [ "${MIGRATE_IP}" == "TRUE" ]; then
     print_msg "Migrating ${DB_BACKUP_NAME} from ${OLD_IP} to ${NEW_IP}"
     sed -i '' "s/${OLD_IP}/${NEW_IP}/g" ${APPS_DIR_SQL}
     print_msg "Importing ${BACKUP_NAME} into ${DB_BACKUP_NAME}"
  if [ "${MIGRATE_GATEWAY}" != "TRUE" ]; then
     if (( $DB_VERSION >= 104 )); then
        echo "before mysql >104"      
        iocage exec "${JAIL}" "mysql -u root "${DATABASE_NAME}" < "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
     else
        echo "before mysql <104"
        iocage exec "${JAIL}" "mysql -u root -p${DB_ROOT_PASSWORD} "${DATABASE_NAME}" < "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
     fi
  fi
  # edit wp-config.php
     print_msg "Changing ${CONFIG_PHP} password to match new install"
     WPDBPASS=`cat ${CONFIG_PHP} | grep DB_PASSWORD | cut -d \' -f 4`
     sed -i '' "s|${WPDBPASS}|${DB_PASSWORD}|" ${CONFIG_PHP}
fi
if [ "${MIGRATE_GATEWAY}" == "TRUE" ]; then
     print_msg "Migrating ${DB_BACKUP_NAME} from ${OLD_GATEWAY} to ${NEW_GATEWAY}"
     sed -i '' "s/${OLD_GATEWAY}/${NEW_GATEWAY}/g" ${APPS_DIR_SQL}
     print_msg "Importing ${BACKUP_NAME} into ${DB_BACKUP_NAME}"
     if (( $DB_VERSION >= 104 )); then
        iocage exec "${JAIL}" "mysql -u root "${DATABASE_NAME}" < "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
     else
        iocage exec "${JAIL}" "mysql -u root -p${DB_ROOT_PASSWORD} "${DATABASE_NAME}" < "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
     fi
  # edit wp-config.php
     print_msg "Changing ${CONFIG_PHP} password to match new install"
     WPDBPASS=`cat ${CONFIG_PHP} | grep DB_PASSWORD | cut -d \' -f 4`
     sed -i '' "s|${WPDBPASS}|${DB_PASSWORD}|" ${CONFIG_PHP}
#maintenance_deactivate
fi

if [ "${MIGRATE_IP}" != "TRUE" ] && [ "${MIGRATE_GATEWAY}" != "TRUE" ]; then

   print_msg "Restore Database No Migration"
     if (( $DB_VERSION >= 104 )); then
        iocage exec "${JAIL}" "mysql -u root "${DATABASE_NAME}" < "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
     else
        iocage exec "${JAIL}" "mysql -u root -p${DB_ROOT_PASSWORD} "${DATABASE_NAME}" < "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
     fi
#maintenance_deactivate
   print_msg "The database ${DB_BACKUP_NAME} has been restored restarting"
fi
maintenance_deactivate
   iocage restart ${JAIL}
   echo
else
  print_err "Must enter '(B)ackup' to backup Wordpress or '(R)estore' to restore app directory: "
  echo
fi

