FROM php:7.4-fpm
MAINTAINER Aslam Idrisov <aslam@malsa.ch>

# Install general utilities
RUN apt-get update \
	&& apt-get install -y \
		vim \
		net-tools \
		procps \
		telnet \
		libpcre3-dev \
		libonig-dev \
		libxml2-dev \
		netcat \
		libzip-dev \
		multiarch-support \
	&& rm -r /var/lib/apt/lists/*

RUN apt-get update \
	&& apt-get install -y \
		imagemagick \
		graphicsmagick \
		zip \
		unzip \
		wget \
		curl \
		git \
		mariadb-client \
		moreutils \
		dnsutils \
		ffmpeg \
	&& rm -rf /var/lib/apt/lists/*

# gd
RUN buildRequirements="libpng-dev libjpeg-dev libfreetype6-dev" \
	&& apt-get update && apt-get install -y ${buildRequirements} \
	&& docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/lib \
	&& docker-php-ext-install gd \
	&& apt-get purge -y ${buildRequirements} \
	&& rm -rf /var/lib/apt/lists/*

# pdo_mysql
RUN docker-php-ext-install pdo_mysql

# mysqli
RUN docker-php-ext-install mysqli

# mbstring
RUN docker-php-ext-install mbstring


# intl
RUN buildRequirements="libicu-dev g++" \
	&& apt-get update && apt-get install -y ${buildRequirements} \
	&& docker-php-ext-install intl \
	&& apt-get purge -y ${buildRequirements} \
	&& runtimeRequirements="libicu63" \
	&& apt-get install -y --auto-remove ${runtimeRequirements} \
	&& rm -rf /var/lib/apt/lists/*

# yaml
RUN buildRequirements="libyaml-dev" \
	&& apt-get update && apt-get install -y ${buildRequirements} \
	&& pecl install yaml \
	&& echo "extension=yaml.so" > /usr/local/etc/php/conf.d/ext-yaml.ini \
	&& apt-get purge -y ${buildRequirements} \
	&& rm -rf /var/lib/apt/lists/*

# imagick
RUN runtimeRequirements="libmagickwand-6.q16-dev --no-install-recommends" \
	&& apt-get update && apt-get install -y ${runtimeRequirements} \
	&& ln -s /usr/lib/x86_64-linux-gnu/ImageMagick-6.8.9/bin-Q16/MagickWand-config /usr/bin/ \
	&& pecl install imagick-3.4.3 \
	&& echo "extension=imagick.so" > /usr/local/etc/php/conf.d/ext-imagick.ini \
	&& rm -rf /var/lib/apt/lists/*

# opcache
RUN docker-php-ext-install opcache


# zip
RUN buildRequirements="zlib1g-dev" \
	&& apt-get update && apt-get install -y ${buildRequirements} \
	&& docker-php-ext-install zip \
	&& apt-get purge -y ${buildRequirements} \
	&& rm -rf /var/lib/apt/lists/*

# redis
RUN wget -O /tmp/redis.tar.gz https://github.com/phpredis/phpredis/archive/3.0.0.tar.gz \
	&& mkdir -p /tmp/redis \
	&& tar xzf /tmp/redis.tar.gz -C /tmp/redis --strip-components=1 \
	&& cd /tmp/redis \
	&& phpize \
	&& ./configure \
	&& make \
	&& make install \
	&& echo "extension=redis.so" > /usr/local/etc/php/conf.d/ext-redis.ini \
	&& rm -rf /tmp/redis.tar.gz /tmp/redis

# APCu
RUN pecl install apcu \
	&& echo "extension=apcu.so\napc.enable_cli = 1" > /usr/local/etc/php/conf.d/ext-apcu.ini

# create symlink to support standard /usr/bin/php
RUN ln -s /usr/local/bin/php /usr/bin/php

# locales
ADD assets/locale.gen /etc/locale.gen
RUN apt-get update \
	&& apt-get install -y locales \
	&& rm -r /var/lib/apt/lists/*

# Activate login for user www-data
RUN chsh www-data -s /bin/bash

# new home folder for user
RUN usermod -d /data/web/releases/current www-data


ADD assets/php-fpm.conf /usr/local/etc/php-fpm.conf
ADD assets/php.ini /usr/local/etc/php/conf.d/php.ini
ADD assets/.env.docker /opt/docker/.env.docker
ADD assets/entrypoint.sh /entrypoint.sh
ADD assets/bin /usr/local/bin

# Cron
RUN apt-get update \
	&& apt-get install -y cron \
	&& rm -rf /var/lib/apt/lists/*


#####################################
# Exif:
#####################################

ARG INSTALL_EXIF=true
RUN if [ ${INSTALL_EXIF} = true ]; then \
	# Enable Exif PHP extentions requirements
	docker-php-ext-install exif && \
	 docker-php-ext-enable exif \
;fi


WORKDIR /data/web/releases/current

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]