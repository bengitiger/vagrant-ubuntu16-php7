#!/usr/bin/env bash

# Load helpers
source /vagrant/scripts/helpers.sh

info "Restarting MariaDB..."
service mysql restart &> /dev/null

info "Restarting nginx..."
service nginx restart &> /dev/null

info "Restarting php7.0-fpm..."
service php7.0-fpm restart &> /dev/null
