#!/usr/bin/env bash

# Use single quotes instead of double quotes to make it work with special-character passwords
PASSWORD='12345678'
PROJECTFOLDER='platform'

# Create project folder, written in 3 single mkdir-statements to make sure this runs everywhere without problems
mkdir "/var/www"
mkdir "/var/www/html"
mkdir "/var/www/html/${PROJECTFOLDER}"

apt-get install -y apache2
apt-get install -y php5

debconf-set-selections <<< "mysql-server mysql-server/root_password password $PASSWORD"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $PASSWORD"
apt-get -y install mysql-server
apt-get install php5-mysql

debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $PASSWORD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $PASSWORD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $PASSWORD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
apt-get -y install phpmyadmin

# setup hosts file
VHOST=$(cat <<EOF
<VirtualHost *:80>
    DocumentRoot "/var/www/html/${PROJECTFOLDER}/public"
    <Directory "/var/www/html/${PROJECTFOLDER}/public">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
)
echo "${VHOST}" > /etc/apache2/sites-available/000-default.conf

# enable mod_rewrite
a2enmod rewrite

# restart apache
apache2 restart

# install curl (needed to use git afaik)
apt-get -y install curl php5-curl

# install openssl (needed to clone from GitHub, as github is https only)
apt-get -y install openssl

# install PHP GD, the graphic lib (we create captchas and avatars)
apt-get -y install php5-gd

# install git
apt-get -y install git

# git clone HUGE
git clone https://github.com/KimGen/platform "/var/www/html/${PROJECTFOLDER}"

# install Composer
wget -s https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# go to project folder, load Composer packages
cd "/var/www/html/${PROJECTFOLDER}"
composer install

# run SQL statements from install folder
mysql -h "localhost" -u "root" "-p${PASSWORD}" < "/var/www/html/${PROJECTFOLDER}/application/_installation/01-create-database.sql"
mysql -h "localhost" -u "root" "-p${PASSWORD}" < "/var/www/html/${PROJECTFOLDER}/application/_installation/02-create-table-users.sql"
mysql -h "localhost" -u "root" "-p${PASSWORD}" < "/var/www/html/${PROJECTFOLDER}/application/_installation/03-create-table-notes.sql"

# writing rights to avatar folder
chmod 0777 -R "/var/www/html/${PROJECTFOLDER}/public/avatars"

# remove Apache's default demo file
rm "/var/www/html/index.html"

# final feedback
echo "Voila!"
