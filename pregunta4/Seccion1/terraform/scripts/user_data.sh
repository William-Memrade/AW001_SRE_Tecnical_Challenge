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
cat << 'EOF' > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Web App ALB</title>
</head>
<body>
    <h1>Estos servidores son elásticos</h1>
</body>
</html>
EOF

# 7. Instalar Node Exporter (expone métricas del sistema en :9100 para Prometheus)
useradd --no-create-home --shell /bin/false node_exporter || true
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xzf node_exporter-1.7.0.linux-amd64.tar.gz
cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf node_exporter-1.7.0.linux-amd64*

cat << 'EOF' > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# 8. Habilitar y arrancar nginx
systemctl enable nginx
systemctl restart nginx

echo "Configuración finalizada exitosamente."
echo "- Nginx activo en puerto 80"
