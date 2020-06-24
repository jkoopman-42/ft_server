FROM debian:buster

# Install needed packages
RUN apt update && \
	apt upgrade && \
	apt install -y \
		wget \
		nginx \
		sendmail \
		mariadb-server mariadb-client \
		filter openssl \
		php7.3-fpm php-curl php-date php-dom php-ftp php-gd php-iconv php-json \
		php-mbstring php-mysqli php-posix php-sockets php-tokenizer \
		php-xml php-xmlreader php-zip php-simplexml

# Download PHPMyAdmin, Unpack & move
RUN wget https://files.phpmyadmin.net/phpMyAdmin/4.9.3/phpMyAdmin-4.9.3-all-languages.tar.gz && \
	tar -zxvf phpMyAdmin-4.9.3-all-languages.tar.gz && \
	rm phpMyAdmin-4.9.3-all-languages.tar.gz && \
	mv phpMyAdmin-4.9.3-all-languages /var/www/html/phpmyadmin

# Install Nginx config
COPY srcs/default /etc/nginx/sites-available/default

# Install PHPMyAdmin config
COPY srcs/phpmyadmin_config.php /var/www/html/phpmyadmin/config.inc.php

# Sign & Install SSL certificate
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/localhost.key -out /etc/ssl/certs/localhost.crt \
	-subj "/C=NL/ST=Noord-Holland/L=Amsterdam/O=Development/CN=localhost"

# Setup PHPMyAdmin config & database (+User)
RUN service mysql start && \
	mysql < /var/www/html/phpmyadmin/sql/create_tables.sql -u root && \
	mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' IDENTIFIED BY 'admin' WITH GRANT OPTION;FLUSH PRIVILEGES;" && \
	mysql -e "CREATE DATABASE wordpress;GRANT ALL PRIVILEGES ON wordpress.* TO 'admin'@'localhost' IDENTIFIED BY 'admin';FLUSH PRIVILEGES;" && \
	chmod 660 /var/www/html/phpmyadmin/config.inc.php

# Install Wordpress
RUN service mysql start && \
	wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -P /var/www/html/ && \
	chmod +x /var/www/html/wp-cli.phar && \
	mv /var/www/html/wp-cli.phar /usr/local/bin/wp && \
	cd /var/www/html/ && \
	wp core download --allow-root && \
	wp config create --dbname=wordpress --dbuser=admin --dbpass=admin --allow-root && \
	wp core install --allow-root --url="/"  --title="My Sexy Blog Title" --admin_user="admin" --admin_password="admin" --admin_email="admin@jkctech.nl" && \
	mysql -e "USE wordpress;UPDATE wp_options SET option_value='https://localhost/' WHERE option_name='siteurl' OR option_name='home';" && \
	rm /var/www/html/index.nginx-debian.html /var/www/html/readme.html /var/www/html/wp-config-sample.php

# Change PHP upload size
RUN sed -i 's,^post_max_size =.*$,post_max_size = 10M,' /etc/php/7.3/fpm/php.ini && \
	sed -i 's,^upload_max_filesize =.*$,upload_max_filesize = 10M,' /etc/php/7.3/fpm/php.ini

# Own webroot by webuser
RUN chown -R www-data:www-data /var/www

EXPOSE 80 443 110

COPY srcs/startup.sh ~/startup.sh

ENTRYPOINT ["/bin/bash", "~/startup.sh"]