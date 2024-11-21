#!/bin/bash

# Установим переменные
AST_VERSION="22.0.0"  # Укажите нужную версию
LOG_DIR="/var/log/asterisk_install"
SRC_DIR="/usr/src/asterisk"
INSTALL_DIR="/usr/local/asterisk"

# Создаём папки для логов
mkdir -p "$LOG_DIR"
mkdir -p "$SRC_DIR"

# Функция обработки ошибок
handle_error() {
    echo "Ошибка на этапе: $1. Смотрите логи: $LOG_DIR/$2.log"
    exit 1
}

# Обновление системы
echo "Обновляем систему..."
dnf update -y > "$LOG_DIR/update.log" 2>&1 || handle_error "Обновление системы" "update"

# Установка необходимых пакетов
echo "Устанавливаем зависимости..."
dnf groupinstall -y "Development Tools" >> "$LOG_DIR/dependencies.log" 2>&1 || handle_error "Установка Development Tools" "dependencies"
dnf install -y epel-release wget tar ncurses-devel libxml2-devel sqlite-devel chkconfig >> "$LOG_DIR/dependencies.log" 2>&1 || handle_error "Установка зависимостей" "dependencies"
dnf --enablerepo=crb install jansson-devel doxygen >> "$LOG_DIR/dependencies.log" 2>&1 || handle_error "Установка зависимостей2" "dependencies2"

# Загрузка исходников Asterisk
echo "Загружаем исходники Asterisk..."
cd "$SRC_DIR" || exit
wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-"$AST_VERSION".tar.gz -O "$SRC_DIR/asterisk.tar.gz" >> "$LOG_DIR/download.log" 2>&1 || handle_error "Загрузка исходников" "download"

# Распаковка исходников
echo "Распаковываем исходники..."
tar -xvf asterisk.tar.gz >> "$LOG_DIR/extract.log" 2>&1 || handle_error "Распаковка исходников" "extract"
cd asterisk-"$AST_VERSION" || exit

# Установка зависимостей Asterisk через скрипт
echo "Устанавливаем зависимости Asterisk..."
contrib/scripts/install_prereq install >> "$LOG_DIR/asterisk_deps.log" 2>&1 || handle_error "Установка зависимостей Asterisk" "asterisk_deps"

# Конфигурация Asterisk
echo "Конфигурируем Asterisk..."
./configure --prefix="$INSTALL_DIR" >> "$LOG_DIR/configure.log" 2>&1 || handle_error "Конфигурация Asterisk" "configure"

# Сборка Asterisk
echo "Собираем Asterisk..."
make -j$(nproc) >> "$LOG_DIR/build.log" 2>&1 || handle_error "Сборка Asterisk" "build"

# Установка Asterisk
echo "Устанавливаем Asterisk..."
make install >> "$LOG_DIR/install.log" 2>&1 || handle_error "Установка Asterisk" "install"

# Установка конфигурационных файлов
echo "Устанавливаем конфигурационные файлы..."
make samples >> "$LOG_DIR/samples.log" 2>&1 || handle_error "Установка конфигурационных файлов" "samples"

# Установка автозапуска
echo "Настраиваем автозапуск Asterisk..."
make config >> "$LOG_DIR/config_service.log" 2>&1 || handle_error "Настройка автозапуска" "config_service"

# Запуск Asterisk
echo "Запускаем Asterisk..."
systemctl enable asterisk >> "$LOG_DIR/service_enable.log" 2>&1 || handle_error "Включение сервиса Asterisk" "service_enable"
systemctl start asterisk >> "$LOG_DIR/service_start.log" 2>&1 || handle_error "Запуск Asterisk" "service_start"

echo "Установка завершена успешно. Логи находятся в $LOG_DIR."
