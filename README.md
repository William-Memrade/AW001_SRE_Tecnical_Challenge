# SRE Technical Challenge - AWS Kubernetes & Observability

Este proyecto contiene la solución completa para el reto técnico de Ingeniero SRE. Implementa un clúster de Kubernetes auto-gestionado en AWS, una flota de servidores elásticos con Terraform, y un stack completo de observabilidad.

---

## 📂 Estructura del Proyecto

El proyecto está organizado siguiendo los requerimientos del reto técnico:

```text
AW001_SRE_Technical_Challenge/
│
├── azure-pipelines/            # Pipelines de CI/CD (KOps y Terraform)
│
├── pregunta1/                  # Clúster de Kubernetes
│   ├── Seccion1/kops/          # Scripts de aprovisionamiento con KOps
│   └── Evidencias/             # Capturas de pantalla
│
├── pregunta2/                  # Despliegue Nativo (Manifestos)
│   ├── Seccion1/kubernetes/    # YAMLs: Deployment, HPA, Service, ConfigMap
│   ├── Seccion1/scripts/       # Script de despliegue automatizado
│   └── Evidencias/             # Capturas de pantalla
│
├── pregunta3/                  # Despliegue Helm
│   ├── Seccion1/helm/          # values-nginx.yaml para Bitnami Nginx
│   └── Evidencias/             # Capturas de pantalla
│
├── pregunta4/                  # IaC con Terraform (Flota Elástica)
│   ├── Seccion1/terraform/     # Código Terraform (VPC, ASG, ALB, IAM)
│   └── Evidencias/             # Capturas de pantalla
│
├── pregunta5/                  # Observabilidad (Full Stack)
│   ├── Seccion1/observabilidad/# Configs para Prometheus y OTel
│   └── Evidencias/             # Capturas de pantalla
│
└── README.md
```

---

## 🛠️ Tecnologías y Herramientas

- **Infraestructura K8s**: KOps (instancias EC2 t3.small).
- **IaC Complementaria**: Terraform (para la red y flota de servidores externos al clúster).
- **Observabilidad**: 
    - **Grafana**: Dashboards centralizados.
    - **Prometheus**: Métricas de clúster y nodos externos (EC2 SD).
    - **Alertmanager**: Gestión de alertas.
    - **OpenTelemetry (OTel)**: Recolección de trazas y logs.
    - **Loki**: Agregación de logs.
    - **Tempo**: Almacenamiento de trazas distribuidas.

---

## 🚀 Automatización (CI/CD)

El despliegue está totalmente automatizado mediante **Azure Pipelines**:

1. **`azure-pipeline-kops.yml`**: 
   - Aprovisiona el clúster KOps.
   - Despliega el stack de observabilidad completo.
   - Despliega las aplicaciones (Pregunta 2 y 3).
   - Imprime todas las URLs públicas (Grafana, Prometheus, etc.).
   
2. **`azure-pipeline-terraform.yml`**:
   - Aprovisiona la VPC y la flota elástica de servidores web.
   - Configura seguridad (auditd, chrony) y monitoreo (node_exporter) en los servidores.

---

## 📊 Acceso a Herramientas de Observabilidad

Al finalizar el pipeline de KOps, se imprimirán las URLs públicas asignadas por AWS Load Balancers:

- **Grafana**: `http://<ALB-DNS>` (User: `admin` / Pass: `admin`)
- **Prometheus**: `http://<ALB-DNS>:9090`
- **Alertmanager**: `http://<ALB-DNS>:9093`
- **OTel Collector**: Endpoint API en port `4318` (HTTP) y `4317` (gRPC).

---

## ✅ Características Destacadas

1. **Auto-escalado**: HPA configurado para escalar pods basados en consumo de RAM.
2. **Rolling Updates**: Estrategia de actualización sin tiempo de inactividad.
3. **Seguridad**: Servidores con auditoría activa (`auditd`) y sincronización de tiempo (`chrony`).
4. **Service Discovery**: Prometheus detecta automáticamente los nodos de Terraform mediante tags de AWS.
5. **Limpieza Controlada**: Stage de `Destroy` incluido en los pipelines para eliminar recursos de AWS y evitar costos innecesarios.
