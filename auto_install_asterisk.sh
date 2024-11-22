#!/bin/bash

# Скрипт установки Asterisk на AlmaLinux 9.3

LOG_DIR="/var/log/asterisk_install"
SRC_DIR="/usr/src/asterisk"
ASTERISK_VERSION="22.1.0"

# Создание каталога для логов
mkdir -p $LOG_DIR
mkdir -p $SRC_DIR

echo "Установка необходимых пакетов..."
dnf install -y epel-release dnf-plugins-core >> $LOG_DIR/install.log 2>&1
dnf --enablerepo=crb install -y \
    wget \
    tar \
    ncurses-devel \
    libuuid-devel \
    jansson-devel \
    libxml2-devel \
    sqlite-devel \
    gcc \
    gcc-c++ \
    make \
    git \
    openssl-devel \
    newt-devel \
    kernel-devel \
    patch \
    libedit-devel \
    libtool \
    speex-devel \
    opus-devel \
    dmidecode \
    doxygen >> $LOG_DIR/install.log 2>&1

if [ $? -ne 0 ]; then
    echo "Ошибка при установке пакетов. Подробности в $LOG_DIR/install.log"
    exit 1
fi

echo "Загрузка и распаковка исходников Asterisk версии $ASTERISK_VERSION..."
cd $SRC_DIR
wget -O asterisk.tar.gz "http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-$ASTERISK_VERSION.tar.gz" >> $LOG_DIR/download.log 2>&1
if [ $? -ne 0 ]; then
    echo "Ошибка загрузки Asterisk. Проверьте лог: $LOG_DIR/download.log"
    exit 1
fi

tar -xzf asterisk.tar.gz >> $LOG_DIR/extract.log 2>&1
cd "asterisk-$ASTERISK_VERSION"

echo "Установка зависимостей через скрипт install_prereq..."
./contrib/scripts/install_prereq install >> $LOG_DIR/prereq.log 2>&1

echo "Настройка сборки Asterisk..."
./configure --libdir=/usr/lib64 >> $LOG_DIR/configure.log 2>&1
if [ $? -ne 0 ]; then
    echo "Ошибка конфигурации. Проверьте лог: $LOG_DIR/configure.log"
    exit 1
fi

echo "Сборка Asterisk..."
make -j$(nproc) >> $LOG_DIR/build.log 2>&1
if [ $? -ne 0 ]; then
    echo "Ошибка сборки. Проверьте лог: $LOG_DIR/build.log"
    exit 1
fi

echo "Установка Asterisk..."
make install >> $LOG_DIR/install.log 2>&1
make samples >> $LOG_DIR/samples.log 2>&1
make config >> $LOG_DIR/config_service.log 2>&1
ldconfig >> $LOG_DIR/ldconfig.log 2>&1

echo "Создание пользователя и группы для Asterisk..."
groupadd asterisk
useradd -r -d /var/lib/asterisk -s /sbin/nologin -g asterisk asterisk

echo "Настройка прав для каталогов..."
chown -R asterisk:asterisk /var/lib/asterisk /var/spool/asterisk /var/log/asterisk
chmod -R 750 /var/lib/asterisk /var/spool/asterisk /var/log/asterisk

echo "Обновление конфигурации для использования пользователя asterisk..."
sed -i 's/^;runuser = .*/runuser = asterisk/' /etc/asterisk/asterisk.conf
sed -i 's/^;rungroup = .*/rungroup = asterisk/' /etc/asterisk/asterisk.conf

echo "Копирование systemd файла и его активация..."
cp contrib/systemd/asterisk.service /etc/systemd/system/
sed -i 's|/usr/sbin/asterisk|/usr/local/asterisk/sbin/asterisk|' /etc/systemd/system/asterisk.service
systemctl daemon-reload
systemctl enable asterisk >> $LOG_DIR/enable_service.log 2>&1

echo "Запуск Asterisk..."
systemctl start asterisk
if [ $? -eq 0 ]; then
    echo "Asterisk успешно установлен и запущен."
else
    echo "Ошибка запуска Asterisk. Проверьте статус: systemctl status asterisk"
    exit 1
fi
