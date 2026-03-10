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

# 7. Instalar OpenTelemetry Collector
echo "Instalando OpenTelemetry Collector..."
wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.95.0/otelcol-contrib_0.95.0_linux_amd64.deb
dpkg -i otelcol-contrib_0.95.0_linux_amd64.deb

cat << 'EOF' > /etc/otelcol-contrib/config.yaml
receivers:
  filelog:
    include: [ /var/log/nginx/access.log, /var/log/nginx/error.log ]
  hostmetrics:
    collection_interval: 10s
    scrapers:
      cpu:
      memory:
processors:
  batch:
exporters:
  otlp:
    # URL DEL INGRESS O LOAD BALANCER DEL CLUSTER K8s (A REEMPLAZAR LUEGO CON EL DNS CORRECTO)
    endpoint: "otel-collector.observability.svc.cluster.local:4317"
    tls:
      insecure: true
service:
  pipelines:
    logs:
      receivers: [filelog]
      processors: [batch]
      exporters: [otlp]
    metrics:
      receivers: [hostmetrics]
      processors: [batch]
      exporters: [otlp]
EOF

systemctl enable otelcol-contrib
systemctl restart otelcol-contrib

# Reiniciar y habilitar nginx
systemctl enable nginx
systemctl restart nginx

echo "Configuración finalizada exitosamente."
