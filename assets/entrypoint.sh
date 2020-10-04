#!/bin/bash

VHOST_ROOT=/data/web/releases/current/

#
# Import SSL-Certificates
# Custom CAs in /usr/local/share/ca-certificates/*.crt
#
update-ca-certificates
update-ca-certificates --fresh


#
# Configure MSMTP
#
SSMTP_SETTINGS_PATH=/etc/msmtprc
/bin/sed -i "s@{{ SSMTP_MAILHUB }}@${SSMTP_MAILHUB}@" ${SSMTP_SETTINGS_PATH}


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
# Wait for DB
#
if [ ! -z ${DB_PORT_3306_TCP_ADDR} ] ; then
	until nc -z ${DB_PORT_3306_TCP_ADDR} ${DB_PORT_3306_TCP_PORT}; do
		echo "$(date) - Waiting for db..."
		sleep 1
	done
fi


#
# Import Dump
#
if [ ! -z ${IMPORT_MYSQL_DUMP} ] ; then
	MYSQL_TABLE_COUNT=`mysql --host="${DB_PORT_3306_TCP_ADDR}" --port="${DB_PORT_3306_TCP_PORT}" --user="${DB_ENV_MYSQL_USER}" --password="${DB_ENV_MYSQL_PASSWORD}" --database="${DB_ENV_MYSQL_DATABASE}" --execute="SHOW TABLES;" --batch --skip-column-names | wc -l`
	if [ "${MYSQL_TABLE_COUNT}" == "0" ] ; then
		echo "Importing mysql dump ${IMPORT_MYSQL_DUMP}..."
		mysql --host="${DB_PORT_3306_TCP_ADDR}" --port="${DB_PORT_3306_TCP_PORT}" --user="${DB_ENV_MYSQL_USER}" --password="${DB_ENV_MYSQL_PASSWORD}" --database="${DB_ENV_MYSQL_DATABASE}" < ${IMPORT_MYSQL_DUMP}
		echo "done."
	else
		echo "There's already data in the database. Aborting."
	fi
fi

#
# CONFIGURE
#
case ${APPLICATION_TYPE} in

	LARAVEL)
		DOCUMENT_ROOT=${VHOST_ROOT}public/
		SETTINGS_PATH=${VHOST_ROOT}/.env
	;;
	YII2)
		DOCUMENT_ROOT=${VHOST_ROOT}web/
	;;
	TYPO3_7|TYPO3_8)
		DOCUMENT_ROOT=${VHOST_ROOT}web/
		cd ${DOCUMENT_ROOT}../Configuration/
		ln -snf ${TYPO3_CONTEXT} current
		;;
	FLOW|FLOW_3|FLOW_4|NEOS|NEOS_2)
		DOCUMENT_ROOT=${VHOST_ROOT}Web/
		SETTINGS_PATH=${VHOST_ROOT}Configuration/${FLOW_CONTEXT}/Settings.yaml

		mkdir -p ${VHOST_ROOT}Configuration/ ${VHOST_ROOT}Data/ ${VHOST_ROOT}Web/
		chown -R ${USER}:${GROUP} ${VHOST_ROOT}Configuration/ ${VHOST_ROOT}Data/ ${VHOST_ROOT}Web/
		chmod -R u+rwx,g+rwx ${VHOST_ROOT}Configuration/ ${VHOST_ROOT}Data/ ${VHOST_ROOT}Web/

		if [ ! -f ${SETTINGS_PATH}.docker ];
		then
			cp /opt/docker/Settings.yaml.docker ${SETTINGS_PATH}.docker
			cp /opt/docker/.env.docker ${SETTINGS_PATH}.docker
		fi
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

	/bin/sed -i "s@{{ ELASTICSEARCH_HOST }}@elasticsearch@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ ELASTICSEARCH_PORT }}@${ELASTICSEARCH_PORT_9200_TCP_PORT}@" ${SETTINGS_PATH}

	/bin/sed -i "s@{{ PRIMARY_DOMAIN }}@${PRIMARY_DOMAIN}@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ PRIMARY_SCHEMA }}@${PRIMARY_SCHEMA}@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ HOSTNAME }}@`hostname`@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ TRUSTED_HOSTS_PATTERN }}@${TRUSTED_HOSTS_PATTERN}@" ${SETTINGS_PATH}

	/bin/sed -i "s@{{ ENCRYPTION_KEY }}@${ENCRYPTION_KEY}@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ APP_KEY }}@${APP_KEY}@" ${SETTINGS_PATH}

	/bin/sed -i "s@{{ PIWIK_URL }}@${PIWIK_URL}@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ PIWIK_TOKEN }}@${PIWIK_TOKEN}@" ${SETTINGS_PATH}

	/bin/sed -i "s@{{ TYPO3_CONTEXT }}@${TYPO3_CONTEXT}@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ FLOW_CONTEXT }}@${FLOW_CONTEXT}@" ${SETTINGS_PATH}
	/bin/sed -i "s@{{ LARAVEL_CONTEXT }}@${LARAVEL_CONTEXT}@" ${SETTINGS_PATH}
done


#
# PREPARE
#

case ${APPLICATION_TYPE} in
	LARAVEL)
		su ${USER} export -c "LARAVEL_CONTEXT=${LARAVEL_CONTEXT} ${VHOST_ROOT}php artisan cache:clear"
		su ${USER} export -c "LARAVEL_CONTEXT=${LARAVEL_CONTEXT} ${VHOST_ROOT}php artisan route:clear"	
	;;
	YII2)
	;;
	TYPO3_7|TYPO3_8)
		cd ${DOCUMENT_ROOT}
		mkdir -p fileadmin typo3conf typo3temp/{GB,llxml,temp,_temp_,user_upload} typo3temp_processed_ uploads/{media,pics,tf}
		chown -R ${USER}:${GROUP} fileadmin typo3conf typo3temp typo3temp_processed_ uploads

		# Clear cache
		rm -f typo3cache/temp_CACHED_*
		find typo3temp/ -type f -delete
		mysql --host="${DB_PORT_3306_TCP_ADDR}" --port="${DB_PORT_3306_TCP_PORT}" --user="${DB_ENV_MYSQL_USER}" --password="${DB_ENV_MYSQL_PASSWORD}" --database="${DB_ENV_MYSQL_DATABASE}" --batch --execute="SHOW TABLES;" | grep -E "^(cache|cf)" | while read T; do
			mysql --host="${DB_PORT_3306_TCP_ADDR}" --port="${DB_PORT_3306_TCP_PORT}" --user="${DB_ENV_MYSQL_USER}" --password="${DB_ENV_MYSQL_PASSWORD}" --database="${DB_ENV_MYSQL_DATABASE}" --batch --execute="TRUNCATE TABLE ${T};"
		done
	;;
	FLOW|FLOW_2|FLOW_3|NEOS|NEOS_2)
		cd ${VHOST_ROOT}
		mkdir -p Data Web
		chown -R ${USER}:${GROUP} Configuration Data Web
		find Data/Temporary/ -type f -name Lock -delete
		find Data/Temporary/ -type f -name Flow.lock -delete
		rm Configuration/PackageStates.php
		find Configuration -type f -name "IncludeCachedConfigurations.php" -delete
		rm Web/_Resources/Persistent/*
		rm Web/_Resources/Static/Packages/*

		su ${USER} export -c "FLOW_CONTEXT=${FLOW_CONTEXT} ${VHOST_ROOT}flow flow:cache:flush --force"
		su ${USER} export -c "FLOW_CONTEXT=${FLOW_CONTEXT} ${VHOST_ROOT}flow doctrine:migrate --force"
		su ${USER} export -c "FLOW_CONTEXT=${FLOW_CONTEXT} ${VHOST_ROOT}flow cache:warmup --force"

		su ${USER} export -c "FLOW_CONTEXT=${FLOW_CONTEXT} ${VHOST_ROOT}flow node:repair"

		su ${USER} export -c "FLOW_CONTEXT=${FLOW_CONTEXT} ${VHOST_ROOT}flow nodeindex:cleanup --force"
		su ${USER} export -c "FLOW_CONTEXT=${FLOW_CONTEXT} php -d memory_limit=1024M ${VHOST_ROOT}flow nodeindex:build --workspace live --force" || echo "Error while indexing" &
	;;
	HTML|PHP|PHPFOX)
	;;
esac


#
# NEOS 2.0 Specific commands
#

if [ ${APPLICATION_TYPE} = "NEOS_2" ]; then
	su ${USER} export -c "FLOW_CONTEXT=${FLOW_CONTEXT} ${VHOST_ROOT}flow resource:publish"
fi


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