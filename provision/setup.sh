#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

vagrant_user=$(echo "$1")

# Load helpers
source /vagrant/scripts/helpers.sh

# Load settings.yaml
eval $(parse_yaml /vagrant/config/settings.yaml "config_")

# Create the swap space 2GB
create_swap() {
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  swapon -s
  echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
}

# Configure timezone and locales
configure_timezone_and_locales() {
  echo "${config_timezone}" > /etc/timezone
  if [ ${config_box} = "ubuntu/xenial64" ]; then
    ln -fs "/usr/share/zoneinfo/${config_timezone}" /etc/localtime
  fi

  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
  dpkg-reconfigure --frontend noninteractive tzdata
  export LANGUAGE=en_US.UTF-8
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  locale-gen en_US.UTF-8
  dpkg-reconfigure locales
}

add_ppa_repositories() {
  info "Adding ppa:git-core/ppa repository"
  add-apt-repository -y ppa:git-core/ppa &>/dev/null

  # Update apt-get info.
  apt-get update &>/dev/null
}

# Install python properties
install_python_properties() {
  apt-get install -y python-software-properties software-properties-common &>/dev/null
  apt-get update &>/dev/null
}

not_installed() {
  dpkg -s "$1" 2>&1 | grep -q 'Version:'
  if [[ "$?" -eq 0 ]]; then
    apt-cache policy "$1" | grep 'Installed: (none)'
    return "$?"
  else
    return 0
  fi
}

print_pkg_info() {
  local pkg="$1"
  local pkg_version="$2"
  local space_count
  local pack_space_count
  local real_space

  space_count="$(( 20 - ${#pkg} ))" #11
  pack_space_count="$(( 30 - ${#pkg_version} ))"
  real_space="$(( space_count + pack_space_count + ${#pkg_version} ))"
  printf " * $pkg %${real_space}.${#pkg_version}s ${pkg_version}\n"
}

apt_package_install_list=()

apt_package_check_list=(
  # base packages
  build-essential
  git
  zip
  unzip
  ngrep
  curl
  make
  vim
  colordiff
  pkg-config
  libmagickwand-dev
  imagemagick
  g++
  nodejs

  # ntp service to keep clock current
  ntp

  # Req'd for i18n tools
  gettext

  # dos2unix
  # Allows conversion of DOS style line endings to something we'll have less
  # trouble with in Linux.
  dos2unix

  # nginx is installed as the default web server
  nginx

  # memcached is made available for object caching
  memcached

  # Base packages for php7.0.
  php7.0-fpm
  php7.0-cli

  # Common and dev packages for php
  php7.0-common
  php7.0-dev

  # Extra PHP modules that we find useful
  php-memcached
  php7.0-bz2
  php7.0-curl
  php7.0-gd
  php7.0-imap
  php7.0-intl
  php7.0-json
  php7.0-ldap
  php7.0-mbstring
  php7.0-mcrypt
  php7.0-mysql
  php7.0-opcache
  php7.0-soap
  php7.0-sqlite3
  php7.0-xml
  php7.0-xmlrpc
  php7.0-zip

  # Latex
  #texlive-full
)

install_imagick_to_php7() {
  wget --quiet https://github.com/mkoppanen/imagick/archive/phpseven.zip -O phpseven.zip
  unzip phpseven.zip
  cd imagick-phpseven
  phpize > /dev/null 2>&1
  ./configure > /dev/null 2>&1
  make > /dev/null 2>&1
  make install > /dev/null 2>&1
  echo "extension=imagick.so" > /etc/php/7.0/mods-available/imagick.ini
  ln -sf /etc/php/7.0/mods-available/imagick.ini /etc/php/7.0/fpm/conf.d/20-imagick.ini
  ln -sf /etc/php/7.0/mods-available/imagick.ini /etc/php/7.0/cli/conf.d/20-imagick.ini
  cd ..
  rm -rf phpseven.zip imagick-phpseven
}

install_xdebug_to_php7() {
  wget --quiet -c "http://xdebug.org/files/xdebug-2.4.0.tgz"
  tar -xf xdebug-2.4.0.tgz
  cd xdebug-2.4.0/
  phpize > /dev/null 2>&1
  ./configure > /dev/null 2>&1
  make > /dev/null 2>&1
  make install > /dev/null 2>&1
  echo "zend_extension=xdebug.so" > /etc/php/7.0/mods-available/xdebug.ini
  ln -sf /etc/php/7.0/mods-available/xdebug.ini /etc/php/7.0/fpm/conf.d/20-xdebug.ini
  ln -sf /etc/php/7.0/mods-available/xdebug.ini /etc/php/7.0/cli/conf.d/20-xdebug.ini
  cd ..
  rm -rf xdebug-2.4.0.tgz xdebug-2.4.0
}

# Install Composer PHP
install_composer_php() {
  curl -sS "https://getcomposer.org/installer" | php
  sudo chmod +x "composer.phar"
  sudo mv "composer.phar" "/usr/local/bin/composer"
}

# Install MariaDB
install_mariaDB() {
  # Remove MySQL
  apt-get remove -y --purge mysql-server mysql-client mysql-common
  apt-get autoremove -y
  apt-get autoclean

  rm -rf /var/lib/mysql
  rm -rf /var/log/mysql
  rm -rf /etc/mysql

  # Add Maria PPA
  apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
  add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://ftp.osuosl.org/pub/mariadb/repo/10.1/ubuntu xenial main'
  apt-get update

  # Set The Automated Root Password
  debconf-set-selections <<< "mariadb-server-10.1 mysql-server/data-dir select ''"
  debconf-set-selections <<< "mariadb-server-10.1 mysql-server/root_password password 123456"
  debconf-set-selections <<< "mariadb-server-10.1 mysql-server/root_password_again password 123456"

  # Install MariaDB
  apt-get install -y mariadb-server

  # Configure Password Expiration
  echo "default_password_lifetime = 0" >> /etc/mysql/my.cnf
}

install_node_modules() {
  npm install -g pm2 > /dev/null 2>&1
  npm install -g grunt-cli > /dev/null 2>&1
  npm install -g gulp-cli > /dev/null 2>&1
  npm install -g bower > /dev/null 2>&1
  npm install -g browser-sync > /dev/null 2>&1
}

package_check() {
  local pkg
  local pkg_version

  for pkg in "${apt_package_check_list[@]}"; do
    if not_installed "${pkg}"; then
      echo " *" "$pkg" [not installed]
      apt_package_install_list+=($pkg)
    else
      pkg_version=$(dpkg -s "${pkg}" 2>&1 | grep 'Version:' | cut -d " " -f 2)
      print_pkg_info "$pkg" "$pkg_version"
    fi
  done
}

package_install() {
  package_check

  if [[ ${#apt_package_install_list[@]} = 0 ]]; then
    info "No apt packages to install"
  else
    # Install required packages
    info "Installing apt-get packages..."
    apt-get -y install ${apt_package_install_list[@]}

    # Remove unnecessary packages
    info "Removing unnecessary packages..."
    apt-get autoremove -y

    # Clean up apt caches
    apt-get clean
  fi

  # Install php7.0-imagick if it is not yet available.
  if [ ! -f "/etc/php/7.0/cli/conf.d/20-imagick.ini" ]; then
    info "Installing php7.0-imagick"
    install_imagick_to_php7
  fi

  # Install xdebug if it is not yet available.
  if [ ! -f "/etc/php/7.0/mods-available/xdebug.ini" ]; then
    info "Installing xdebug"
    install_xdebug_to_php7
  fi

  # Install Composer if it is not yet available.
  if [[ ! -n "$(composer --version --no-ansi | grep 'Composer version')" ]]; then
    info "Installing Composer..."
    install_composer_php
    noroot composer global require --no-progress "fxp/composer-asset-plugin:~1.2.0"
  fi

  info "Installing node modules..."
  install_node_modules

  info "Installing MariaDB..."
  install_mariaDB
}

configure_packages() {
  # Add github token
  info "Your personal GitHub token is set for Composer."
  noroot composer config --global github-oauth.github.com ${config_github_token}

  # Git
  noroot git config --global color.status auto
  noroot git config --global color.branch auto
  noroot git config --global color.interactive auto
  noroot git config --global color.diff auto

  # PHP CLI
  if [ ! -f "/vagrant/config/php7/php-cli.ini" ]; then
    contents=$(< /vagrant/provision/templates/php7/php-cli.ini)
    contents=$(echo "$contents" | sed -e "s@\$TIMEZONE@$config_timezone@g")
    echo "$contents" > /vagrant/config/php7/php-cli.ini
  fi
  ln -fs /vagrant/config/php7/php-cli.ini /etc/php/7.0/cli/conf.d/99-custom.ini

  # PHP FPM
  if [ ! -f "/vagrant/config/php7/php-fpm.ini" ]; then
    contents=$(< /vagrant/provision/templates/php7/php-fpm.ini)
    contents=$(echo "$contents" | sed -e "s@\$TIMEZONE@$config_timezone@g")
    echo "$contents" > /vagrant/config/php7/php-fpm.ini
  fi
  ln -fs /vagrant/config/php7/php-fpm.ini /etc/php/7.0/fpm/conf.d/99-custom.ini

  # nginx
  if [ ! -f "/vagrant/config/nginx/nginx.conf" ]; then
    cp /vagrant/provision/templates/ngnix/nginx.conf /vagrant/config/nginx/nginx.conf
    rm -rf /etc/nginx/nginx.conf
  fi
  ln -fs /vagrant/config/nginx/nginx.conf /etc/nginx/nginx.conf
}

info "Provisioning Box..."

# Retrieve the Nginx signing key from nginx.org
wget --quiet "http://nginx.org/keys/nginx_signing.key" -O- | apt-key add -

# Apply the nodejs signing key
apt-key adv --quiet --keyserver "hkp://keyserver.ubuntu.com:80" --recv-key C7917B12 2>&1 | grep "gpg:"
apt-key export C7917B12 | apt-key add -

# Apply the PHP signing key
apt-key adv --quiet --keyserver "hkp://keyserver.ubuntu.com:80" --recv-key E5267A6C 2>&1 | grep "gpg:"
apt-key export E5267A6C | apt-key add -

# nodejs
wget -qO- https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
add-apt-repository -y https://deb.nodesource.com/node_6.x

info "Update packages list and upgrade system"
system_update

info "Creating 2GB swap space in /swapfile..."
create_swap

info "Configure timezone and locales"
configure_timezone_and_locales

info "Install python properties"
install_python_properties

# Add ppa repositories
add_ppa_repositories

# install packages
package_install

# configure packages
configure_packages

echo "Provisioning complete"
