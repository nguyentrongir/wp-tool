#!/bin/bash

VERSION="1.3.0-ultra"
LOGFILE="/var/log/wp-ultra-tool.log"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BRANCH_URL="https://raw.githubusercontent.com/nguyentrongir/wp-tool/refs/heads/ultra/wp-tool.sh"

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
    read -p "Xac nhan PHUC HOI CORE? (yes): " C
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

    log "Harden WP $WEB"
    echo "Da harden WordPress"
}

# -------------------------------
# Lock / Unlock Permission
# -------------------------------

lock_wp_perm() {
    read -p "Nhap folder web: " WEB

    if [ ! -d "$WEB" ]; then
        echo "❌ Thu muc khong ton tai: $WEB"
        return
    fi

    echo "🔒 Lock permission WordPress..."

    find "$WEB" -type d -exec chmod 555 {} \;
    find "$WEB" -type f -exec chmod 444 {} \;

    [ -f "$WEB/wp-config.php" ] && chmod 400 "$WEB/wp-config.php"
    [ -f "$WEB/.htaccess" ] && chmod 444 "$WEB/.htaccess"

    log "Lock permission $WEB"
    echo "✅ Da LOCK permission"
}

unlock_wp_perm() {
    read -p "Nhap folder web: " WEB

    if [ ! -d "$WEB" ]; then
        echo "❌ Thu muc khong ton tai: $WEB"
        return
    fi

    echo "🔓 Unlock permission WordPress..."

    find "$WEB" -type d -exec chmod 755 {} \;
    find "$WEB" -type f -exec chmod 644 {} \;

    [ -f "$WEB/wp-config.php" ] && chmod 640 "$WEB/wp-config.php"
    [ -f "$WEB/.htaccess" ] && chmod 644 "$WEB/.htaccess"

    log "Unlock permission $WEB"
    echo "✅ Da UNLOCK permission"
}

# -------------------------------
# WP-CLI Functions
# -------------------------------

check_install_wpcli() {
    if command -v wp >/dev/null 2>&1; then
        echo "✅ WP-CLI da ton tai:"
        wp --version --allow-root
    else
        echo "❌ Chua co WP-CLI. Dang cai..."
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        mv wp-cli.phar /usr/local/bin/wp
        echo "✅ Da cai WP-CLI:"
        wp --version --allow-root
    fi
}

update_wpcli() {
    if command -v wp >/dev/null 2>&1; then
        echo "🔄 Dang update WP-CLI..."
        wp cli update --yes --allow-root
        wp --version --allow-root
    else
        echo "❌ Chua co WP-CLI. Tien hanh cai moi..."
        check_install_wpcli
    fi
}

install_plugin_menu() {
    read -p "Nhap folder web: " WEB

    if [ ! -d "$WEB" ]; then
        echo "❌ Thu muc khong ton tai: $WEB"
        return
    fi

    check_install_wpcli

    echo "Chon cach cai plugin:"
    echo "1) Cai tu thu vien WordPress"
    echo "2) Cai tu file ZIP"
    read -p "Lua chon: " OPT

    echo "🔓 Unlock permission de cai plugin..."
    find "$WEB" -type d -exec chmod 755 {} \;
    find "$WEB" -type f -exec chmod 644 {} \;
    [ -f "$WEB/wp-config.php" ] && chmod 640 "$WEB/wp-config.php"

    cd "$WEB" || return

    case $OPT in
        1)
            read -p "Nhap ten plugin (vd: wordfence): " PLUGIN
            wp plugin install "$PLUGIN" --activate --allow-root
            ;;
        2)
            read -p "Nhap duong dan file zip (vd: /root/plugin.zip): " ZIPFILE
            if [ ! -f "$ZIPFILE" ]; then
                echo "❌ File zip khong ton tai!"
                return
            fi
            wp plugin install "$ZIPFILE" --activate --allow-root
            ;;
        *)
            echo "Lua chon khong hop le!"
            return
            ;;
    esac

    echo "🔒 Lock lai permission..."
    find "$WEB" -type d -exec chmod 555 {} \;
    find "$WEB" -type f -exec chmod 444 {} \;
    [ -f "$WEB/wp-config.php" ] && chmod 400 "$WEB/wp-config.php"

    log "Install plugin on $WEB"
    echo "✅ Cai plugin xong va da lock lai"
}

# -------------------------------
# Self Update (branch ultra)
# -------------------------------

self_update() {
    echo "🔄 Dang cap nhat wp-tool tu branch ultra..."

    TMP_FILE="/tmp/wp-tool.sh"

    wget -q -O "$TMP_FILE" "$BRANCH_URL"

    if [ $? -ne 0 ]; then
        echo "❌ Tai file that bai"
        return
    fi

    chmod +x "$TMP_FILE"
    cp "$TMP_FILE" "$0"

    log "Self update wp-tool from ultra"
    echo "✅ Cap nhat thanh cong"
    echo "👉 Hay chay lai: $0"
    exit 0
}

deploy_git_theme_from_root() {
    read -p "Nhap root web (vd: /var/www/html): " WEB
    read -p "Nhap ten theme (vd: blocksy-child): " THEME_NAME

    THEME_PATH="$WEB/wp-content/themes/$THEME_NAME"

    if [ ! -d "$WEB/.git" ]; then
        echo "❌ Thu muc root khong phai git repo"
        return
    fi

    if [ ! -d "$THEME_PATH" ]; then
        echo "❌ Khong tim thay theme: $THEME_PATH"
        return
    fi

    echo "🚀 Deploy THEME (git o root, chi tac dong theme)..."

    echo "🔓 Unlock theme..."
    find "$THEME_PATH" -type d -exec chmod 755 {} \;
    find "$THEME_PATH" -type f -exec chmod 644 {} \;

    echo "📥 Dang git pull tai root..."
    cd "$WEB" || return
    git pull

    if [ $? -ne 0 ]; then
        echo "❌ Git pull that bai. Khong lock lai!"
        return
    fi

    echo "🔒 Lock lai theme..."
    find "$THEME_PATH" -type d -exec chmod 555 {} \;
    find "$THEME_PATH" -type f -exec chmod 444 {} \;

    echo "✅ Deploy theme thanh cong (root git → chi lock theme)"
}


# -------------------------------
# Main Menu
# -------------------------------

while true; do
    clear
    echo "==============================="
    echo "   WP Ultra Tool - WordPress   "
    echo "   Version: $VERSION"
    echo "==============================="
    echo "1) Backup All"
    echo "2) Restore Core"
    echo "3) Harden WP"
    echo "4) 🔒 Lock WP Permissions"
    echo "5) 🔓 Unlock WP Permissions"
    echo "6) 🔄 Update wp-tool (branch ultra)"
    echo "7) 🎨 Deploy THEME (git o root, chi tac dong theme)"
    echo "8) 📦 Cai / Kiem tra WP-CLI"
    echo "9) 🔄 Update WP-CLI"
    echo "10) 🔌 Cai Plugin (auto unlock/lock)"
    echo "0) Exit"
    echo "-------------------------------"
    read -p "Chon: " choice

    case $choice in
        1) backup_all ;;
        2) restore_core ;;
        3) harden_wp ;;
        4) lock_wp_perm ;;
        5) unlock_wp_perm ;;
        6) self_update ;;
        7) deploy_git_theme_from_root ;;
        8) check_install_wpcli ;;
        9) update_wpcli ;;
        10) install_plugin_menu ;;
        0) exit 0 ;;
        
      
        *) echo "Lua chon khong hop le!" ;;
    esac

    pause
done
