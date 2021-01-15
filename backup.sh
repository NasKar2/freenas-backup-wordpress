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

escaped_passwords () {
ESCAPED_WPDBPASS=$(printf '%s\n' "$WPDBPASS" | sed -e 's/[]\/$*.^|[]/\\&/g');
ESCAPED_DB_PASSWORD=$(printf '%s\n' "$DB_PASSWORD" | sed -e 's/[]\/$*.^|[]/\\&/g');
sed -i '' "s/$ESCAPED_WPDBPASS/$ESCAPED_DB_PASSWORD/" ${CONFIG_PHP}
}

jail_test () {
JAIL_TEST=$(iocage get type $JAIL)
if ! [ "$JAIL_TEST" = "jail" ]; then
 print_err "The jail ${JAIL} does not exist"
 exit 1
fi
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
FIND_DIR=""
OLD_IP=""
NEW_IP=""
OLD_GATEWAY=""
NEW_GATEWAY=""
MAX_NUM_BACKUPS=0

# Check if backup-config exists and read the file
  SCRIPT=$(readlink -f "$0")
  SCRIPTPATH=$(dirname "$SCRIPT")
  . $SCRIPTPATH/backup-config

# Check if backup-config created correctly or set defaults
if [ -z $POOL_PATH ]; then
  POOL_PATH="/mnt/$(iocage get -p)"
  print_msg "POOL_PATH defaulting to "$POOL_PATH
  pool_trim=$POOL_PATH"/"
fi
if [ -z $FIND_DIR ]; then
  FIND_DIR=$pool_trim
  print_msg "FIND_DIR is ${FIND_DIR}"
else
  FIND_DIR=$POOL_PATH/$FIND_DIR
  print_msg "FIND_DIR is ${FIND_DIR}"  
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
   sed -i '' "s|OLD_GATEWAY=.*||g" ./backup-config
   sed -i '' "s|NEW_GATEWAY=.*||g" ./backup-config
   print_msg "Remove GATEWAY addresses from backup-config file as migration doesn't need to be repeated"
fi

# Get all wordpress installs and place jail name in array_jail and apps location in array_apps
    unset apps_loc
    WP_INSTALL=`find ${FIND_DIR} -name "wp-config.php"`
    apps_loc=($WP_INSTALL)
    for i in "${!apps_loc[@]}"; do
        host="${apps_loc[i]}"
        if [[ "$host" == *"iocage"* ]]; then
                unset apps_loc[i]
        fi
    done
    for diff_install in "${apps_loc[@]}"; do
       diff_install=${diff_install#$pool_trim}
       diff_install=${diff_install%/wp-config.php}
       diff_install=${diff_install%/files}
       auto_jail=${diff_install##*/}
       auto_apps=${diff_install%/*}
          if [[ "$auto_jail" == "$auto_apps" ]]; then
              auto_apps="/"
          fi
       array_jail+=("${auto_jail}")
       array_apps+=("${auto_apps}")
    done
if [[ $# = 0 ]] && [[ ! -z $JAIL_NAME ]]; then
   unset array_arg
   array_arg=(${JAIL_NAME})
         for arg in "${!array_arg[@]}"; do
              value="${array_arg[$arg]}"
            for i in "${!array_jail[@]}"; do
                if [[ "${array_jail[$i]}" = "${value}" ]]; then
                  arg_apps_tmp="${array_apps[$i]}"
                  arg_apps="${arg_apps} ${arg_apps_tmp}"
                fi
            if [[ ! "${array_jail[@]}" =~ "${value}" ]]; then
                print_err "The jail ${value} does not exist in the ${FIND_DIR} location, you must set the JAIL_NAME variable for a jail that exists in that location"
                exit 1
                # whatever you want to do when array doesn't contain value
            fi
            done
         done
            #echo "arg_apps=$arg_apps"
            array_arg_apps=(${arg_apps})
            #echo "${array_arg[@]}"
            #echo "${array_arg_apps[@]}"
elif [[ ! $# = 0 ]]; then
  unset array_arg
  for i in $@
   do
   array_arg+=($i)
  done
   #echo "There were $# arguments"
   #for dir in "${array_arg[@]}"; do echo $dir; done
         for arg in "${!array_arg[@]}"; do
          value="${array_arg[$arg]}"
            for i in "${!array_jail[@]}"; do
                if [[ "${array_jail[$i]}" = "${value}" ]]; then
                  arg_apps_tmp="${array_apps[$i]}"
                  arg_apps="${arg_apps} ${arg_apps_tmp}"
                fi
           # done
           #echo "value=${value}"
           #echo "array_arg=${array_arg[arg]}"
            if [[ ! "${array_jail[@]}" =~ "${value}" ]]; then
                print_err "The jail ${value} does not exist in the ${FIND_DIR} location, you must list an argument for a jail that exists in that location"
                exit 1
                # whatever you want to do when array doesn't contain value
            fi
            done
         done
           #echo "arg_apps=$arg_apps"
           array_arg_apps=(${arg_apps})
           #echo "${array_arg[@]}"
           #echo "${array_arg_apps[@]}"
else
         array_arg=("${array_jail[@]}")
         array_arg_apps=("${array_apps[@]}")
        # echo "array_arg=${array_arg[@]}"
        # echo "array_arg_apps=${array_arg_apps[@]}"
fi

#
# Start loop for all jails
#
  for arg in "${!array_arg[@]}"; do 
    JAIL="${array_arg[$arg]}"
    APPS_PATH="${array_arg_apps[$arg]}"
#echo "JAIL=${JAIL}"
if [ $APPS_PATH != "/" ]; then
    APPS_PATH="/"$APPS_PATH
fi
#echo "APPS_PATH=${APPS_PATH}"
# Check if Jail exists and loop thru all selected jails
     jail_test
# Check is Jail is down
   if [ $(iocage get -s ${JAIL} ) = "down" ]; then                   
     print_err "The jail named ${JAIL} is down please start it"
     exit 1
   fi
# Check if "/root/${JAIL}_db_password.txt" exists
   if [[ ! -e "/root/${JAIL}_db_password.txt" ]]; then
        print_err "The password file '/root/${JAIL}_db_password.txt' does not exist"
        exit 1
   fi
# Check for the correct passwords in the password file
# Reset PASSWORDS
   DB_ROOT_PASSWORD=""
   DB_PASSWORD=""

   DB_VERSION="$(iocage exec ${JAIL} "mysql -V | cut -d ' ' -f 6  | cut -d . -f -2")"
   DB_VERSION="${DB_VERSION//.}"
#   version[i]=$DB_VERSION
#   echo "version is $version[$i]"
   i=$((i+1))
#  print_err "Database Version is "${DB_VERSION}
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
      DB_PASSWORD=`cat /root/${JAIL}_db_password.txt | grep DB_PASSWORD | cut -d '"' -f2`
      if (( $DB_VERSION >= 104 )); then
         if [ -z "${DB_PASSWORD}" ]; then
            print_err "The password file DB_VERSION >= 10.4 is corrupt."
         fi
      else
         DB_ROOT_PASSWORD=`cat /root/${JAIL}_db_password.txt | grep DB_ROOT_PASSWORD | cut -d '"' -f2`
         if [ -z "${DB_ROOT_PASSWORD}" ] || [ -z "${DB_PASSWORD}" ]; then
            print_err "The password file DB_VERSION < 10.4 is corrupt."
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

   done

# Bash Menu Backup Restore

# Ask to Backup or restore, if run interactively
if ! [ -t 1 ] ; then
  # Not run interactively
  choice="B"

elif [ "${MIGRATE_IP}" == "TRUE" ]; then
  choice="R"
  print_msg "A Migration has been chosen so will go to (R)estore automatically"
else
  read -p "Enter '(B)ackup' to backup Nextcloud or '(R)estore' to restore Nextcloud: " choice
  while [ "$choice" != "B" ] && [ "$choice" != "b" ] && [ "$choice" != "R" ] && [ "$choice" != "r" ];
   do
     if [ "$choice" != "B" ] && [ "$choice" != "b" ] && [ "$choice" != "R" ] && [ "$choice" != "r" ]; then
       #clear
       print_err "You need to enter 'B' or 'R'"
#     else
#       break
     fi
   read -p "Enter '(B)ackup' to backup Nextcloud or '(R)estore' to restore Nextcloud: " choice
  done
fi
echo
DATE=$(date +'_%F_%H%M')
# BACKUP choice

if [ "$choice" = "B" ] || [ "$choice" = "b" ]; then
# LOOP BACKUP #
  for arg in "${!array_arg[@]}"; do
    JAIL="${array_arg[$arg]}"
    APPS_PATH="${array_arg_apps[$arg]}"
if [ $APPS_PATH != "/" ]; then
    APPS_PATH="/"$APPS_PATH
fi
   BACKUP_NAME="${JAIL}${DATE}.tar.gz"
   print_msg "Backing up ${JAIL} to ${BACKUP_NAME}"
# Check if ${POOL_PATH}${APPS_PATH}/${JAIL} exists
   if [ ! -d "${POOL_PATH}${APPS_PATH}/${JAIL}" ]; then
#        mkdir -p $RESTORE_DIR
         print_err "${POOL_PATH}${APPS_PATH}/${JAIL} does not exist. You are trying to backup a data directory that doesn't exist."
         exit 1
#        print_msg "Create directory ${RESTORE_DIR}"
   fi

# Read the password file.
# Reset PASSWORDS
   DB_ROOT_PASSWORD=""
   DB_PASSWORD=""
   #   . "/root/${JAIL}_db_password.txt"
   DB_PASSWORD=`cat /root/${JAIL}_db_password.txt | grep DB_PASSWORD | cut -d '"' -f2`
   DB_ROOT_PASSWORD=`cat /root/${JAIL}_db_password.txt | grep DB_ROOT_PASSWORD | cut -d '"' -f2`
  # DB_VERSION=${version[$i]}
#   print_err "Current DB_VERSION is "${DB_VERSION}
   phar_install
   maintenance_activate
   if (( $DB_VERSION >= 104 )); then
      iocage exec ${JAIL} "mysqldump --single-transaction -h localhost -u "root" "${DATABASE_NAME}" > "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
   else
      iocage exec ${JAIL} "mysqldump --single-transaction -h localhost -u "root" -p"${DB_ROOT_PASSWORD}" "${DATABASE_NAME}" > "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
   fi  
      print_msg "${JAIL} database backup ${DB_BACKUP_NAME} complete"
if [[ "${FILES_PATH}" = "/" ]]; then
  #echo "tar -czf ${POOL_PATH}/backup/${JAIL}/${BACKUP_NAME} -C ${POOL_PATH}${APPS_PATH}/${JAIL} ."
   tar -czf ${POOL_PATH}/backup/${JAIL}/${BACKUP_NAME} -C ${POOL_PATH}${APPS_PATH}/${JAIL} .
else
  #   echo "tar -czf ${POOL_PATH}/backup/${JAIL}/${BACKUP_NAME} -C ${POOL_PATH}${APPS_PATH}/${JAIL}/${FILES_PATH} ."
      tar -czf ${POOL_PATH}/backup/${JAIL}/${BACKUP_NAME} -C ${POOL_PATH}${APPS_PATH}/${JAIL}/${FILES_PATH} .

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
#echo "${#array_arg[@]}"
if [[ "${#array_arg[@]}" > "1" ]]; then
echo "There are ${#array_arg[@]} jails available to restore, pick the one to restore"; \
select JAIL in "${array_arg[@]}"; do echo; break; done
while [[ ! $REPLY -le ${#array_arg[@]} ]] || [[ ! "$REPLY" =~ ^[0-9]+$ ]] || [[ ! "$REPLY" -ne 0 ]];
do
if [[ ! $REPLY -le ${#array_arg[@]} ]] || [[ ! "$REPLY" =~ ^[0-9]+$ ]] || [[ ! "$REPLY" -ne 0 ]]; then
  #clear
  print_err "$REPLY is invalid try again"
fi                                                                         
select JAIL in "${array_arg[@]}"; do echo; done
done
REPLY=$((REPLY-1))
#for dir in "${array_arg[@]}"; do echo $dir; done
APPS_PATH="${array_arg_apps[$REPLY]}"
if [ $APPS_PATH != "/" ]; then
    APPS_PATH="/"$APPS_PATH
fi
print_msg "You choose the jail '${JAIL}' to restore at '$POOL_PATH$APPS_PATH'"
#fi
DB_VERSION="$(iocage exec ${JAIL} "mysql -V | cut -d ' ' -f 6  | cut -d . -f -2")"
DB_VERSION="${DB_VERSION//.}"
#done

fi
# Read the password file.
# Reset PASSWORDS
DB_ROOT_PASSWORD=""
DB_PASSWORD=""
#   . "/root/${JAIL}_db_password.txt"
DB_PASSWORD=`cat /root/${JAIL}_db_password.txt | grep DB_PASSWORD | cut -d '"' -f2`
DB_ROOT_PASSWORD=`cat /root/${JAIL}_db_password.txt | grep DB_ROOT_PASSWORD | cut -d '"' -f2`
RESTORE_DIR=${POOL_PATH}${APPS_PATH}/${JAIL}
if [[ "${FILES_PATH}" = "/" ]]; then
   APPS_DIR_SQL=${RESTORE_DIR}/${DB_BACKUP_NAME}
   CONFIG_PHP="${RESTORE_DIR}/wp-config.php"
else
   APPS_DIR_SQL=${RESTORE_DIR}/${FILES_PATH}/${DB_BACKUP_NAME}
   CONFIG_PHP="${RESTORE_DIR}/${FILES_PATH}/wp-config.php"
fi
backupMainDir="${POOL_PATH}/${BACKUP_PATH}"
# Check if RESTORE_DIR exists
   if [ ! -d "$RESTORE_DIR" ]
   then
#         mkdir -p $RESTORE_DIR
         print_err "$RESTORE_DIR does not exist. You must set the JAIL_NAME variable in the config to name of the wordpress DATA directory"
         print_err "This will be in the ${POOL_PATH}${APPS_PATH} directory"
         exit 1
#         print_msg "Create directory ${RESTORE_DIR}"
   fi

# Pick the restore file *don't edit this section*
cd "${POOL_PATH}/${BACKUP_PATH}/${JAIL}"
shopt -s  nullglob
array=(${JAIL}*.tar.gz)
#for dir in "${array[@]}"; do echo; done

#for dir in */; do echo; done

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
     WPDBPASS=`cat ${CONFIG_PHP} | grep DB_PASSWORD | cut -d \' -f 4`
if [ "${MIGRATE_IP}" == "TRUE" ]; then
     print_msg "Migrating ${DB_BACKUP_NAME} from ${OLD_IP} to ${NEW_IP}"
     sed -i '' "s/${OLD_IP}/${NEW_IP}/g" ${APPS_DIR_SQL}
     print_msg "Importing ${BACKUP_NAME} into ${DB_BACKUP_NAME}"

  if [ "${MIGRATE_GATEWAY}" == "TRUE" ]; then
       print_msg "Migrating ${DB_BACKUP_NAME} from ${OLD_GATEWAY} to ${NEW_GATEWAY}"
       sed -i '' "s/${OLD_GATEWAY}/${NEW_GATEWAY}/g" ${APPS_DIR_SQL}
  fi

     if (( $DB_VERSION >= 104 )); then
        echo "before mysql >104"      
        iocage exec "${JAIL}" "mysql -u root "${DATABASE_NAME}" < "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
     else
        echo "before mysql <104"
        iocage exec "${JAIL}" "mysql -u root -p${DB_ROOT_PASSWORD} "${DATABASE_NAME}" < "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
     fi
  
  # edit wp-config.php
     print_msg "Changing ${CONFIG_PHP} password to match new install"
     escaped_passwords
else
   print_msg "Restore Database No Migration"
     if (( $DB_VERSION >= 104 )); then
        iocage exec "${JAIL}" "mysql -u root "${DATABASE_NAME}" < "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
     else
        iocage exec "${JAIL}" "mysql -u root -p${DB_ROOT_PASSWORD} "${DATABASE_NAME}" < "${JAIL_FILES_LOC}/${DB_BACKUP_NAME}""
     fi
   print_msg "The database ${DB_BACKUP_NAME} has been restored restarting"
fi
maintenance_deactivate
   iocage restart ${JAIL}
   echo
else
  echo ""
fi
