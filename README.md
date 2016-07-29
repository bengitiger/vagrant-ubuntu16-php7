# Vagrant Box
A custom Vagrant Box for PHP Web Development.

# Software 

* Ubuntu 16.04 64-bit
* Git 2.x
* PHP 7.0
* Nginx 1.10.x
* MariaDB 10.1.x (root password: 123456)
* Sqlite3
* Composer
* Node.js 6.x (With PM2, Bower, Browsersync, Grunt, and Gulp)
* Memcached

## Installation & Setup
```For Windows is recommended that you run the cmd window as Administrator```

1. Install Git
1. Install [VirtualBox >= 5.0.0](https://www.virtualbox.org/wiki/Downloads)
1. Install [Vagrant >= 1.8.4](https://www.vagrantup.com/downloads.html)
1. git clone https://github.com/wbraganca/vagrant-ubuntu16-php7 vagrant-ubuntu16-php7
1. install Vagrant plugins:
    * vagrant plugin install vagrant-vbguest
    * vagrant plugin install vagrant-hostsupdater
1. Run the `vagrant up` command in your terminal
