#!/bin/bash

LOGFILE="/var/log/wp-ultra-tool.log"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")

log() {
    echo "[$(date +"%F %T")] $1" | tee -a $LOGFILE
}

pause() {
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
    rm -rf $WEB/wp-admin
    rm -rf $WEB/wp-includes
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
Deny from all
php_flag engine off
EOF
    sed -i "/ /root/virus_scan_$DATE.txt
    log "Scan virus $WEB"
    echo "Ket qua luu: /root/virus_scan_$DATE.txt"
}

# -------------------------------
# Lock / Unlock Permission
# -------------------------------

lock_wp_perm() {
    read -p "Nhap folder web: " WEB

    if [ ! -d "$WEB" ]; then
        echo "❌ Thư mục không tồn tại: $WEB"
        return
    fi

    echo "🔒 Lock permission WordPress..."

    # Folder: 555
    find "$WEB" -type d -exec chmod 555 {} \;

    # File: 444
    find "$WEB" -type f -exec chmod 444 {} \;

    # wp-config.php: 400
    if [ -f "$WEB/wp-config.php" ]; then
        chmod 400 "$WEB/wp-config.php"
    fi

    # .htaccess: 444
    if [ -f "$WEB/.htaccess" ]; then
        chmod 444 "$WEB/.htaccess"
    fi

    echo "✅ Đã LOCK permission cho WordPress"
}

unlock_wp_perm() {
    read -p "Nhap folder web: " WEB

    if [ ! -d "$WEB" ]; then
        echo "❌ Thư mục không tồn tại: $WEB"
        return
    fi

    echo "🔓 Unlock permission WordPress..."

    # Folder: 755
    find "$WEB" -type d -exec chmod 755 {} \;

    # File: 644
    find "$WEB" -type f -exec chmod 644 {} \;

    # wp-config.php: 640
    if [ -f "$WEB/wp-config.php" ]; then
        chmod 640 "$WEB/wp-config.php"
    fi

    # .htaccess: 644
    if [ -f "$WEB/.htaccess" ]; then
        chmod 644 "$WEB/.htaccess"
    fi

    echo "✅ Đã UNLOCK permission cho WordPress"
}

# -------------------------------
# Main Menu
# -------------------------------

while true; do
    clear
    echo "==============================="
    echo "   WP Ultra Tool - WordPress   "
    echo "==============================="
    echo "1) Backup All"
    echo "2) Restore Core"
    echo "3) Harden WP"
    echo "4) Create vhost"
    echo "5) Remove vhost"
    echo "6) Update WP"
    echo "7) Scan Virus"
    echo "8) Info WP"
    echo "9) 🔒 Lock WP Permissions"
    echo "10) 🔓 Unlock WP Permissions"
    echo "0) Exit"
    echo "-------------------------------"
    read -p "Chon: " choice

    case $choice in
        1) backup_all ;;
        2) restore_core ;;
        3) harden_wp ;;
        9) lock_wp_perm ;;
        10) unlock_wp_perm ;;
        0) exit 0 ;;
        *) echo "Lua chon khong hop le!" ;;
    esac
    pause
done
