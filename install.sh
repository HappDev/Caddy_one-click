#!/bin/bash

# Цвета для красивого вывода
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Проверка на запуск от имени root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Пожалуйста, запустите скрипт с правами root (sudo ./setup_caddy.sh)${NC}"
  exit 1
fi

echo -e "${CYAN}=== Шаг 1: Установка официального Caddy ===${NC}"
apt update
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

# Добавляем ключ и репозиторий, если они еще не добавлены
if [ ! -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg ]; then
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update
fi

# Установка Caddy
apt install -y caddy

echo ""
echo -e "${CYAN}=== Шаг 2: Настройка домена ===${NC}"
read -p "Введите ваш домен (например, tooc.uk): " DOMAIN

echo ""
echo -e "${CYAN}Что будет обслуживать этот домен?${NC}"
echo "1) Статический сайт (файлы из папки)"
echo "2) Reverse Proxy (проксирование на другой сервер/порт)"
read -p "Введите цифру (1 или 2): " SETUP_CHOICE

# Бэкап старого конфига на всякий случай
cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup

if [ "$SETUP_CHOICE" == "1" ]; then
    echo ""
    read -p "Введите полный путь к папке с сайтом (например, /var/www/mysite): " WEB_ROOT
    
    # Создаем папку, если ее нет
    mkdir -p "$WEB_ROOT"
    
    # Записываем конфиг для статики
    cat <<EOF > /etc/caddy/Caddyfile
$DOMAIN {
    root * $WEB_ROOT
    file_server
}
EOF
    echo -e "${GREEN}Конфиг для статического сайта успешно создан.${NC}"

elif [ "$SETUP_CHOICE" == "2" ]; then
    echo ""
    read -p "Введите адрес целевого сервера (например, http://127.0.0.1:8080 или https://ffr.su): " PROXY_DEST
    
    # Записываем конфиг для прокси
    # Caddy автоматически передает IP (X-Forwarded-For) и схему (X-Forwarded-Proto)
    cat <<EOF > /etc/caddy/Caddyfile
$DOMAIN {
    reverse_proxy $PROXY_DEST {
        header_up Host {http.reverse_proxy.upstream.hostport}
        header_up X-Real-IP {remote_host}
    }
}
EOF
    echo -e "${GREEN}Конфиг для reverse proxy успешно создан.${NC}"

else
    echo -e "${RED}Ошибка: неверный выбор. Изменения в Caddyfile не внесены.${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}=== Шаг 3: Перезапуск Caddy ===${NC}"
systemctl restart caddy
systemctl enable caddy

echo -e "${GREEN}Установка и настройка завершены!${NC}"
echo -e "Caddy запущен и пытается получить SSL сертификат для ${DOMAIN}."
echo -e "Убедитесь, что A-запись вашего домена указывает на IP этого сервера."

