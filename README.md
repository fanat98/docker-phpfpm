# docker-phpfpm

This is a Docker container [fanat98/docker-phpfpm]

## The following modules are installed per default:


Package Name |
------------ |
imagemagick | 
graphicsmagick |
zip |
unzip |
wget |
curl |
git |
mariadb-client |
moreutils |
dnsutils |
ffmpeg |
gd |
pdo_mysql |
mysqli |
mbstring |
intl |
yaml |
opcache |
redis |
APCu |
Cron |
Exif|

#### Custom Settings
The following custom setting were made

|key|value|
|---|--- |
| upload_max_filesize| 384M |
| post_max_size| 384M |
| max_execution_time| 1800 |
| max_input_time| 1800 |
| memory_limit| 1024 |
| expose_php|=Off
| max_input_vars| 5000 |
| realpath_cache_size| 128k |
| short_open_tag| Off |
| display_errors| Off |
| log_errors| On |
| error_log| /data/log/phpfpm/php_errors.log |
| pm | dynamic |
| pm.max_children | 50 |
| pm.start_servers | 4 |
| pm.min_spare_servers | 2 |
| pm.max_spare_servers | 6 |
| pm.max_requests | 500 |

# Maintenance
## Create dumps

You can create dumps (containing htdocs folder, share folder and database dump) with the `dump` command. There are no credentials necessary to run this command. Optionally you can pass a password. Otherwise one will be generated automatically.

* Create dump

```sh
docker exec <DOCKER-CONTAINER-NAME> dump
```

* Create dump with custom password

```sh
docker exec <DOCKER-CONTAINER-NAME> dump iWantToUseThisPasswordInsteadOfAGeneratedOne
```