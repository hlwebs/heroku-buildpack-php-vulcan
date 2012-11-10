#!/bin/bash
# vulcan build -v -c "./vulcan-build-php.sh" -p /app/vendor/build -o apache-${APACHE_VERSION}-php-${PHP_VERSION}.tgz

## EDIT
export S3_BUCKET="heroku-bins"
export LIBMCRYPT_VERSION="2.5.8"
export APC_VERSION="3.1.10"
export PHPREDIS_VERSION="2.2.1"
export PHP_VERSION="5.3.10"
export APACHE_VERSION="2.2.22"
## END EDIT

set -e
set -o pipefail

orig_dir=$( pwd )

mkdir -p build && pushd build

echo "+ Fetching Apache..."
# unpack apache
mkdir -p /app/vendor/apache
curl -L "https://s3.amazonaws.com/${S3_BUCKET}/apache-${APACHE_VERSION}.tgz" -o - | tar xz -C /app/vendor/apache

echo "+ Fetching PHP sources..."
#fetch php, extract
curl -L http://us.php.net/get/php-$PHP_VERSION.tar.bz2/from/www.php.net/mirror -o - | tar xj

pushd php-$PHP_VERSION

echo "+ Configuring PHP..."
# new configure command
## WARNING: libmcrypt needs to be installed.
## WARNING: apache needs to be installed.
./configure \
--prefix=/app/vendor/php \
--with-apxs2=/app/vendor/apache/bin/apxs \
--with-config-file-path=/app/vendor/php \
--enable-gd-native-ttf \
--enable-inline-optimization \
--enable-libxml \
--enable-mbregex \
--enable-mbstring \
--enable-pcntl \
--enable-soap=shared \
--enable-zip \
--with-bz2 \
--with-curl \
--with-gd \
--with-gettext \
--with-jpeg-dir \
--with-iconv \
--with-mhash \
--with-mysql \
--with-mysqli \
--with-openssl \
--with-pcre-regex \
--with-pdo-mysql \
--with-pgsql \
--with-pdo-pgsql \
--with-png-dir \
--with-zlib

echo "+ Compiling PHP..."
# build & install it
make install

popd

# update path
export PATH=/app/vendor/php/bin:$PATH

# configure pear
pear config-set php_dir /app/vendor/php

echo "+ Installing memcache packages..."
set +e
set +o pipefail
pecl config-set php_ini /app/vendor/php/php.ini
yes '' | pecl install -s memcache
# don't forget to add 'extension=memcache.so' to php.ini
set -e
set -o pipefail

echo "+ Installing APC..."
# install apc from source
curl -L http://pecl.php.net/get/APC-${APC_VERSION}.tgz -o - | tar xz
pushd APC-${APC_VERSION}
# php apc jokers didn't update the version string in 3.1.10.
sed -i 's/PHP_APC_VERSION "3.1.9"/PHP_APC_VERSION "3.1.10"/g' php_apc.h
phpize
./configure --enable-apc --enable-apc-filehits --with-php-config=/app/vendor/php/bin/php-config
make && make install
popd

#echo "+ Installing phpredis..."
## install phpredis
#git clone git://github.com/nicolasff/phpredis.git
#pushd phpredis
#git checkout ${PHPREDIS_VERSION}

#phpize
#./configure
#make && make install
## add "extension=redis.so" to php.ini
#popd

echo "+ Packaging PHP..."
# package PHP
echo ${PHP_VERSION} > /app/vendor/php/VERSION

mkdir -p /app/vendor/php/ext
cp /app/vendor/php/lib/php/extensions/no-debug-non-zts-20090626/* /app/vendor/php/ext

pushd /app/vendor/php
mkdir -p /app/vendor/build
tar -zcvf /app/vendor/build/php-${PHP_VERSION}.tgz *
popd

pushd /app/vendor/apache
echo "+ Packaging Apache with php module"
tar -zcvf /app/vendor/build/apache-${APACHE_VERSION}.tgz *

popd

echo "+ Done!"

