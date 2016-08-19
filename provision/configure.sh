#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

vagrant_user=$(echo "$1")

# Load helpers
source /vagrant/scripts/helpers.sh

# Load settings.yaml
eval $(parse_yaml /vagrant/config/settings.yaml "config_")

# Add github token
info "Your personal GitHub token is set for Composer."
noroot composer config --global github-oauth.github.com ${config_github_token}

# PHP CLI
if [ ! -f "/vagrant/config/php7/php-cli.ini" ]; then
  contents=$(< /vagrant/provision/templates/php7/php-cli.ini)
  contents=$(echo "$contents" | sed -e "s@\$TIMEZONE@$config_timezone@g")
  echo "$contents" > /vagrant/config/php7/php-cli.ini
fi
cp /vagrant/config/php7/php-cli.ini /etc/php/7.0/cli/conf.d/99-custom.ini

# PHP FPM
if [ ! -f "/vagrant/config/php7/php-fpm.ini" ]; then
  contents=$(< /vagrant/provision/templates/php7/php-fpm.ini)
  contents=$(echo "$contents" | sed -e "s@\$TIMEZONE@$config_timezone@g")
  echo "$contents" > /vagrant/config/php7/php-fpm.ini
fi
cp /vagrant/config/php7/php-fpm.ini /etc/php/7.0/fpm/conf.d/99-custom.ini
chmod 644 /etc/php/7.0/fpm/conf.d/99-custom.ini

# nginx
if [ ! -f "/vagrant/config/nginx/nginx.conf" ]; then
  cp /vagrant/provision/templates/ngnix/nginx.conf /vagrant/config/nginx/nginx.conf
  rm -rf /etc/nginx/nginx.conf
fi
cp /vagrant/config/nginx/nginx.conf /etc/nginx/nginx.conf
chmod 644 /etc/nginx/nginx.conf

# MariaDB
if [ ! -f "/vagrant/config/mariadb/custom.cnf" ]; then
  cp /vagrant/provision/templates/mariadb/custom.cnf /vagrant/config/mariadb/custom.cnf
fi
cp /vagrant/config/mariadb/custom.cnf /etc/mysql/conf.d/z-custom.cnf
chmod 644 /etc/mysql/conf.d/z-custom.cnf
