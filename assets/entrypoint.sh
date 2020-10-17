#!/bin/bash

VHOST_ROOT=/data/web/releases/current/

#
# Import SSL-Certificates
# Custom CAs in /usr/local/share/ca-certificates/*.crt
#
update-ca-certificates
update-ca-certificates --fresh

#
# user id / group id
#
USERID=${USERID:-33}
USER=${USER:-www-data}
GROUPID=${GROUPID:-33}
GROUP=${GROUP:-www-data}

usermod -l ${USER} www-data
usermod -u ${USERID} -o ${USER}
groupmod -n ${GROUP} www-data
groupmod -g ${GROUPID} -o ${GROUP}

sed -i "s/^user\ =.*/user\ =\ ${USER}/" /usr/local/etc/php-fpm.conf
sed -i "s/^group\ =.*/group\ =\ ${GROUP}/" /usr/local/etc/php-fpm.conf


#
# Server processes
#
FPM_MAX_CHILDREN=${FPM_MAX_CHILDREN:-50}
FPM_START_SERVERS=${FPM_START_SERVERS:-4}
FPM_MIN_SPARE_SERVERS=${FPM_MIN_SPARE_SERVERS:-2}
FPM_MAX_SPARE_SERVERS=${FPM_MAX_SPARE_SERVERS:-6}
FPM_MAX_REQUESTS=${FPM_MAX_REQUESTS:-500}

sed -i "s/^pm\.max_children\ =.*/pm.max_children\ =\ ${FPM_MAX_CHILDREN}/" /usr/local/etc/php-fpm.conf
sed -i "s/^pm\.start_servers\ =.*/pm.start_servers\ =\ ${FPM_START_SERVERS}/" /usr/local/etc/php-fpm.conf
sed -i "s/^pm\.min_spare_servers\ =.*/pm.min_spare_servers\ =\ ${FPM_MIN_SPARE_SERVERS}/" /usr/local/etc/php-fpm.conf
sed -i "s/^pm\.max_spare_servers\ =.*/pm.max_spare_servers\ =\ ${FPM_MAX_SPARE_SERVERS}/" /usr/local/etc/php-fpm.conf
sed -i "s/^pm\.max_requests\ =.*/pm.max_requests\ =\ ${FPM_MAX_REQUESTS}/" /usr/local/etc/php-fpm.conf


#
# Log
#
mkdir -p /data/log/phpfpm
chown -R ${USER}:${GROUP} /data/log/phpfpm


#
# CONFIGURE
#
case ${APPLICATION_TYPE} in

	LARAVEL|SYMFONY)
		DOCUMENT_ROOT=${VHOST_ROOT}public/
		SETTINGS_PATH=${VHOST_ROOT}/.env
	;;
	HTML|PHP|PHPFOX)
		DOCUMENT_ROOT=${VHOST_ROOT}
		;;
	*)
		echo "APPLICATION_TYPE '${APPLICATION_TYPE}' not supported."
		exit 1
esac


TRUSTED_HOSTS_PATTERN=`echo "${DOMAIN_LIST}" | sed "s/,/|/g"`

find ${VHOST_ROOT} -type f -name "*.docker" | while read F
do
	SETTINGS_PATH=`echo "${F}" | sed "s/\.docker$//"`
	cp ${F} ${SETTINGS_PATH}
	/bin/sed -i "s@{{ DB_CONNECTION }}@db@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ DB_HOST }}@db@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ DB_PORT }}@${DB_PORT_3306_TCP_PORT}@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ DB_NAME }}@${DB_ENV_MYSQL_DATABASE}@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ DB_USER }}@${DB_ENV_MYSQL_USER}@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ DB_PASSWORD }}@${DB_ENV_MYSQL_PASSWORD}@" ${SETTINGS_PATH}

	/bin/sed -i "s@{{ PRIMARY_DOMAIN }}@${PRIMARY_DOMAIN}@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ PRIMARY_SCHEMA }}@${PRIMARY_SCHEMA}@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ HOSTNAME }}@`hostname`@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ TRUSTED_HOSTS_PATTERN }}@${TRUSTED_HOSTS_PATTERN}@" ${SETTINGS_PATH}

	/bin/sed -i "s@{{ ENCRYPTION_KEY }}@${ENCRYPTION_KEY}@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ APP_KEY }}@${APP_KEY}@" ${SETTINGS_PATH}

	/bin/sed -i "s@{{ APPLICATION_CONTEXT }}@${APPLICATION_CONTEXT}@" ${SETTINGS_PATH}
done


#
# PREPARE
#

case ${APPLICATION_TYPE} in
	LARAVEL)
		su ${USER} export -c "APPLICATION_CONTEXT=${APPLICATION_CONTEXT} ${VHOST_ROOT}php artisan cache:clear"
		su ${USER} export -c "APPLICATION_CONTEXT=${APPLICATION_CONTEXT} ${VHOST_ROOT}php artisan route:clear"	
	;;
	SYMFONY)
	su ${USER} export -c "APPLICATION_CONTEXT=${APPLICATION_CONTEXT} ${VHOST_ROOT}php bin/console cache:clear"

	;;
	HTML|PHP|PHPFOX)
	;;
esac


#############################
## COMMAND
#############################

if [ "$1" = 'php-fpm' ]; then
	echo "Initialization done."
	echo "Starting..."
	cron -f &
	exec php-fpm
fi

exec "$@"