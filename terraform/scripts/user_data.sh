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
processors:
  batch: {}
exporters:
  otlp:
    endpoint: "otel-collector.observability.svc.cluster.local:4317"
    tls:
      insecure: true
service:
  pipelines:
    logs:
      receivers: [filelog]
      processors: [batch]
      exporters: [otlp]
EOF

systemctl enable otelcol-contrib
systemctl restart otelcol-contrib

# 8. Instalar Node Exporter (Métricas del Servidor Linux / CPU / Memoria)
echo "Instalando Node Exporter..."
useradd --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

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

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# 9. Instalar Prometheus (Base de datos de Métricas)
echo "Instalando Prometheus..."
useradd --no-create-home --shell /bin/false prometheus
mkdir /etc/prometheus
mkdir /var/lib/prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.45.3/prometheus-2.45.3.linux-amd64.tar.gz
tar xvfz prometheus-2.45.3.linux-amd64.tar.gz
cp prometheus-2.45.3.linux-amd64/prometheus /usr/local/bin/
cp prometheus-2.45.3.linux-amd64/promtool /usr/local/bin/
cp -r prometheus-2.45.3.linux-amd64/consoles /etc/prometheus
cp -r prometheus-2.45.3.linux-amd64/console_libraries /etc/prometheus
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

cat << 'EOF' > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 10s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
      
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF
chown prometheus:prometheus /etc/prometheus/prometheus.yml

cat << 'EOF' > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus --config.file /etc/prometheus/prometheus.yml --storage.tsdb.path /var/lib/prometheus/
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

# 10. Instalar Grafana (Dashboards)
echo "Instalando Grafana..."
apt-get install -y apt-transport-https software-properties-common wget
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee -a /etc/apt/sources.list.d/grafana.list
apt-get update -y
apt-get install -y grafana

# Auto-provisionar Prometheus como Datasource en Grafana
cat << 'EOF' > /etc/grafana/provisioning/datasources/prometheus.yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://localhost:9090
    access: proxy
    isDefault: true
EOF

systemctl enable grafana-server
systemctl start grafana-server

# Reiniciar y habilitar nginx
systemctl enable nginx
systemctl restart nginx

echo "Configuración finalizada exitosamente. Múltiples servicios Iniciados:"
echo "- Nginx (80), NodeExporter (9100), Prometheus (9090), Grafana (3000)"

