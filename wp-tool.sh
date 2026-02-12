#!/bin/bash

LOGFILE="/var/log/wp-ultra-tool.log"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")

log() {
    echo "[$(date +"%F %T")] $1" | tee -a $LOGFILE
}

pause(){
    read -p "Nhan ENTER de tiep tuc..."
}

read_db_from_wpconfig() {
    WP="$1/wp-config.php"
    DB_NAME=$(grep DB_NAME $WP | cut -d"'" -f4)
    DB_USER=$(grep DB_USER $WP | cut -d"'" -f4)
    DB_PASS=$(grep DB_PASSWORD $WP | cut -d"'" -f4)
}

backup_all() {
    read -p "Nhap folder web: " WEB
    read_db_from_wpconfig $WEB

    BACKUP_SRC="/root/backup_src_$DATE.tar.gz"
    BACKUP_DB="/root/backup_db_$DB_NAME_$DATE.sql"

    tar -czf $BACKUP_SRC $WEB
    mysqldump -u$DB_USER -p$DB_PASS $DB_NAME > $BACKUP_DB

    log "Backup source + DB: $WEB"
    echo "Backup OK:"
    echo $BACKUP_SRC
    echo $BACKUP_DB
}

restore_core() {
    read -p "Nhap folder web: " WEB
    echo "Xac nhan PHUC HOI CORE? (yes): "
    read C
    [[ "$C" != "yes" ]] && return

    cd /tmp || exit
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz

    rm -rf $WEB/wp-admin $WEB/wp-includes
    cp -r wordpress/wp-admin $WEB/
    cp -r wordpress/wp-includes $WEB/
    cp wordpress/*.php $WEB/

    log "Restore core $WEB"
    echo "Restore core xong"
}

harden_wp() {
    read -p "Nhap folder web: " WEB

    find $WEB -type d -exec chmod 755 {} \;
    find $WEB -type f -exec chmod 644 {} \;
    chmod 600 $WEB/wp-config.php
    chown -R www-data:www-data $WEB

cat > $WEB/.htaccess <<EOF
<Files xmlrpc.php>
Deny from all
</Files>

<Directory $WEB/wp-content/uploads>
php_flag engine off
</Directory>
EOF

    sed -i "/<?php/a define('DISALLOW_FILE_EDIT', true);" $WEB/wp-config.php

    log "Hardening $WEB"
    echo "Bao mat xong"
}

random_salt() {
    read -p "Nhap folder web: " WEB
    SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

    sed -i "/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d" $WEB/wp-config.php
    sed -i "/<?php/a $SALT" $WEB/wp-config.php

    log "Random SALT $WEB"
    echo "Random SALT OK"
}

scan_virus() {
    read -p "Nhap folder web: " WEB
    echo "Dang quet..."
    grep -R --color -nE "eval\(|base64_decode|gzinflate|shell_exec|passthru|system\(" $WEB > /root/virus_scan_$DATE.txt
    log "Scan virus $WEB"
    echo "Ket qua luu: /root/virus_scan_$DATE.txt"
}

create_vhost() {
    read -p "Nhap domain: " DOMAIN
    read -p "Nhap folder web: " WEB

cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root $WEB;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    log "Tao vhost $DOMAIN"
    echo "Vhost tao xong"
}

install_ssl() {
    read -p "Nhap domain: " DOMAIN
    certbot --nginx -d $DOMAIN -d www.$DOMAIN
    log "Cai SSL $DOMAIN"
}

while true
do
clear
echo "=============================="
echo "   WORDPRESS ULTRA TOOL"
echo "=============================="
echo "1. Backup source + DB (auto)"
echo "2. Restore WordPress core"
echo "3. Hardening WordPress"
echo "4. Random SALT key"
echo "5. Scan virus co ban"
echo "6. Tao vhost nginx"
echo "7. Cai SSL Let's Encrypt"
echo "0. Thoat"
echo "=============================="
read -p "Chon: " CH

case $CH in
1) backup_all ;;
2) restore_core ;;
3) harden_wp ;;
4) random_salt ;;
5) scan_virus ;;
6) create_vhost ;;
7) install_ssl ;;
0) exit ;;
*) echo "Sai lua chon" ;;
esac

pause
done
