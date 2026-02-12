#!/bin/bash

LOGFILE="/var/log/wp-pro-tool.log"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")

log() {
    echo "[$(date +"%F %T")] $1" | tee -a $LOGFILE
}

pause(){
    read -p "Nhan ENTER de tiep tuc..."
}

backup_site() {
    read -p "Nhap folder web (vd: /var/www/site): " WEB
    BACKUP_FILE="/root/backup_site_$DATE.tar.gz"
    tar -czf $BACKUP_FILE $WEB
    log "Backup source: $BACKUP_FILE"
    echo "Backup thanh cong: $BACKUP_FILE"
}

backup_db() {
    read -p "Nhap ten database: " DB
    read -p "Nhap user mysql: " USER
    read -p "Nhap password mysql: " PASS
    BACKUP_DB="/root/backup_db_$DB_$DATE.sql"
    mysqldump -u$USER -p$PASS $DB > $BACKUP_DB
    log "Backup DB: $BACKUP_DB"
    echo "Backup DB thanh cong: $BACKUP_DB"
}

create_db() {
    read -p "Nhap mat khau root mysql: " ROOTPASS
    read -p "Nhap ten database: " DB
    read -p "Nhap user: " USER
    read -p "Nhap password user: " PASS

mysql -uroot -p$ROOTPASS <<EOF
CREATE DATABASE $DB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$USER'@'localhost' IDENTIFIED BY '$PASS';
GRANT ALL PRIVILEGES ON $DB.* TO '$USER'@'localhost';
FLUSH PRIVILEGES;
EOF

log "Tao DB: $DB user: $USER"
echo "==== THONG TIN DB ===="
echo "DB: $DB"
echo "User: $USER"
echo "Pass: $PASS"
}

restore_core() {
    read -p "Nhap folder web: " WEB
    echo "Ban chac chan muon PHUC HOI CORE? (yes/no)"
    read CONFIRM
    [[ "$CONFIRM" != "yes" ]] && return

    cd /tmp || exit
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz

    rm -rf $WEB/wp-admin
    rm -rf $WEB/wp-includes

    cp -r wordpress/wp-admin $WEB/
    cp -r wordpress/wp-includes $WEB/
    cp wordpress/*.php $WEB/

    log "Restore WP core cho $WEB"
    echo "Phuc hoi core hoan tat"
}

harden_wp() {
    read -p "Nhap folder web: " WEB

    find $WEB -type d -exec chmod 755 {} \;
    find $WEB -type f -exec chmod 644 {} \;
    chmod 600 $WEB/wp-config.php
    chown -R www-data:www-data $WEB

    sed -i "s/define('DISALLOW_FILE_EDIT'.*/define('DISALLOW_FILE_EDIT', true);/g" $WEB/wp-config.php || true
    grep -q "DISALLOW_FILE_MODS" $WEB/wp-config.php || sed -i "/<?php/a define('DISALLOW_FILE_MODS', true);" $WEB/wp-config.php

    cat > $WEB/.htaccess <<EOF
<Files xmlrpc.php>
Order Deny,Allow
Deny from all
</Files>

<Directory $WEB/wp-content/uploads>
php_flag engine off
</Directory>
EOF

    log "Hardening WP cho $WEB"
    echo "Bao mat WordPress xong"
}

random_salt() {
    read -p "Nhap folder web: " WEB
    SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    sed -i "/AUTH_KEY/d" $WEB/wp-config.php
    sed -i "/SECURE_AUTH_KEY/d" $WEB/wp-config.php
    sed -i "/LOGGED_IN_KEY/d" $WEB/wp-config.php
    sed -i "/NONCE_KEY/d" $WEB/wp-config.php
    sed -i "/AUTH_SALT/d" $WEB/wp-config.php
    sed -i "/SECURE_AUTH_SALT/d" $WEB/wp-config.php
    sed -i "/LOGGED_IN_SALT/d" $WEB/wp-config.php
    sed -i "/NONCE_SALT/d" $WEB/wp-config.php
    sed -i "/<?php/a $SALT" $WEB/wp-config.php
    log "Random SALT cho $WEB"
    echo "Random SALT thanh cong"
}

check_permission() {
    read -p "Nhap folder web: " WEB
    echo "File co quyen sai:"
    find $WEB -type f ! -perm 644
    echo "Folder co quyen sai:"
    find $WEB -type d ! -perm 755
    pause
}

while true
do
clear
echo "===================================="
echo "     WORDPRESS PRO DEVOPS TOOL"
echo "===================================="
echo "1. Tao database + user"
echo "2. Backup source"
echo "3. Backup database"
echo "4. Phuc hoi WordPress core"
echo "5. Bao mat WordPress (hardening)"
echo "6. Random SALT key"
echo "7. Kiem tra permission sai"
echo "0. Thoat"
echo "===================================="
read -p "Chon chuc nang: " CHOICE

case $CHOICE in
1) create_db ;;
2) backup_site ;;
3) backup_db ;;
4) restore_core ;;
5) harden_wp ;;
6) random_salt ;;
7) check_permission ;;
0) exit ;;
*) echo "Lua chon sai!" ;;
esac

pause
done
