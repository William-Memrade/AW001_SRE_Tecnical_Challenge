#!/bin/bash
set -e

# Configurar el registro de salida
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Iniciando configuración del servidor..."

# 1. Crear un usuario de seguridad con privilegios sudo
useradd -m -s /bin/bash security_user
echo "security_user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/security_user

# 2. Actualización completa del sistema
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# 3. Instalar y habilitar NTP (chrony) para sincronización de tiempo
apt-get install -y chrony
systemctl enable chrony
systemctl start chrony

# 4. Instalar y habilitar auditd para auditoría de logs
apt-get install -y auditd
systemctl enable auditd
systemctl start auditd

# 5. Instalar nginx
apt-get install -y nginx

# 6. Configurar el contenido del servidor web
echo "Estos servidores son elásticos" > /var/www/html/index.html

# Reiniciar y habilitar nginx
systemctl enable nginx
systemctl restart nginx

echo "Configuración finalizada exitosamente."
