# Proyecto de Despliegue en Kubernetes (IaC con KOps y Helm)

Este proyecto contiene la infraestructura como código (IaC) para desplegar un clúster de Kubernetes en AWS utilizando **kOps**. Además, se divide en dos fases de despliegue de aplicaciones:
1. **Parte 1 (YAMLs puros):** Despliegue de Nginx y un HPA configurado desde cero.
2. **Parte 2 (Helm):** Despliegue de Nginx usando el chart Open Source de Bitnami con configuraciones customizadas (`values-nginx.yaml`).

Ambas partes cumplen con requerimientos de recursos (CPU 10m, RAM 64Mi) y despliegan dos réplicas mínimas accesibles a través de un LoadBalancer AWS.

---

## Estructura del Proyecto

```text
project-k8s/
│
├── infrastructure/
│   └── kops-cluster.sh       # Script para la creación del clúster con kOps en AWS
│
├── kubernetes/               # PARTE 1: Manifiestos YAML "Puros"
│   ├── configmap.yaml        # ConfigMap para inyectar "Hola Mundo Guillermo"
│   ├── deployment.yaml       # Deployment Nginx, 2 replicas, RollingUpdate y resources
│   ├── service.yaml          # Servicio LoadBalancer para exponer la app en AWS
│   └── hpa.yaml              # Horizontal Pod Autoscaler (HPA basado en RAM al 10%)
│
├── helm/                     # PARTE 2: Helm Charts
│   └── values-nginx.yaml     # Configuración para el Chart Nginx de Bitnami 
│
├── scripts/
│   └── deploy.sh             # Script para aplicar todos los manifiestos de la Parte 1
│
└── README.md                 # Este documento
```

---

## 1. Prerrequisitos Comunes

Asegúrate de tener instaladas las siguientes herramientas en tu entorno local:

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configurado (`aws configure`) con permisos EC2, S3, IAM, VPC, Route53.
- [kOps](https://kops.sigs.k8s.io/getting_started/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm v3+](https://helm.sh/docs/intro/install/) (Requerido para la Parte 2)

---

## 2. Creación del Clúster en AWS con kOps

El script `kops-cluster.sh` dentro de `infrastructure/` automatiza el aprovisionamiento creando primero el bucket de S3 requerido por kOps y luego lanzando el clúster usando instancias EC2 `t2.micro`.

**Comandos:**
```bash
# 1. Ejecutar el script (creará bucket y recursos iniciales)
bash infrastructure/kops-cluster.sh

# 2. kOps actualizará AWS. Este proceso dura ~5 a 10 min.
# Validar si el clúster ya está listo:
kops validate cluster --wait 10m
```

---

## PARTE 1: Desplegando Aplicación con YAML y k8s nativo

Esta parte usa el enfoque declarativo directo con manifests de la carpeta `kubernetes/`. Cumple con Rolling Updates (`maxUnavailable: 0`) y cuota de recursos fijos para interactuar con un Metrics Server y el HPA.

**A. Para Desplegar Automáticamente:**
```bash
chmod +x scripts/deploy.sh
bash scripts/deploy.sh
```

**B. Para Desplegar Manualmente (paso a paso):**
```bash
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/hpa.yaml
```

**C. Comandos de Verificación (Parte 1):**
```bash
# Verificar los pods en ejecución (esperado: 2 pods funcionales)
kubectl get pods

# Verificar el estado del deployment
kubectl describe deployment nginx-deployment

# Obtener DNS del Balanceador de AWS y verificar Service
kubectl get service nginx-service
# IMPORTANTE: Copiar el "EXTERNAL-IP" de Nginx Service y pegarlo en el navegador tras 3 min.

# Verificar métricas de auto-escalamiento basadas en Memoria (10%)
kubectl get hpa
kubectl describe hpa nginx-hpa
```

---

## PARTE 2: Desplegando Aplicación con HELM

Para un caso de uso más estándar de la industria, la Parte 2 utiliza helm y la paquetería open source provista por Bitnami, que aplica mejores prácticas de seguridad por defecto (non-root containers, etc.).

### 1. Instalación de Helm y Repositorios
Si ya tienes binario `helm` en tu terminal, necesitas agregar el repositorio de Bitnami a tu cliente local y actualizar su índice:
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### 2. Comandos para Instalar o Actualizar con Helm

Tu archivo `helm/values-nginx.yaml` se encargará de inyectar 2 réplicas, limitantes de CPU/RAM, un Service `LoadBalancer` y el bloque `serverBlock` que configura la index custom (requerimiento: *"Hola Mundo me gusta jugar con kubernetes"*).

```bash
# A) Instalar el chart Nginx por primera vez pasándole los valores personalizados
helm install mi-nginx bitnami/nginx -f helm/values-nginx.yaml

# B) Listar todas las instalaciones helm activas en este namespace
helm list

# C) Si cambiaste algún valor del archivo YAML temporalmente, aplica los cambios usando Upgrade:
helm upgrade mi-nginx bitnami/nginx -f helm/values-nginx.yaml
```

### 3. Comandos de Verificación (Parte 2)

```bash
# Comprobar el estado del Deployment gestionado por Helm
kubectl get deployment

# Verificar que las dos (2) réplicas solicitadas están corriendo
kubectl get pods

# Comprobar el LoadBalancer creado específicamente por este Release de Helm
kubectl get svc mi-nginx
```

### 4. Accediendo al servidor Web en el Navegador
Para ver *"Hola Mundo me gusta jugar con kubernetes"*, debes ver qué IP te asignó AWS para el LoadBalancer:

1. Ejecuta: `kubectl get svc mi-nginx`
2. En la columna `EXTERNAL-IP` verás una URL del tipo: `abcdefg123-1234.us-east-1.elb.amazonaws.com`.
3. Abre tu navegador (Chrome/Firefox/etc).
4. Pega la URL obtenida en tu barra de direcciones: `http://abcdefg123-1234.us-east-1.elb.amazonaws.com`
*(Nota: AWS puede tardar alrededor de 3 minutos en propagar el DNS del Balanceador nuevo por el mundo).*

---

## Buenas Prácticas de Kubernetes Adoptadas (Compatible v1.28+)

1. **Gestión de Recursos Formal:** Al setear tanto `requests` como `limits` en los Pods, el Planificador (*Scheduler*) de K8s evalúa el espacio disponible del EC2 eficientemente e impide caídas OutOfMemory (OOMKills) inesperadas por monopolio.
2. **Uso de Inyección via Helm `serverBlock`/`ConfigMap`:** De forma nativa inyectamos el proxy/index sin tener que crear, pushear, ni recompilar nuestro propio contenedor Docker (`Dockerfile`), optimizando CI/CD.
3. **Escalamiento Elástico:** Gracias al HPA v2 (recurso consolidado en entornos de v1.23+), podemos escalar pro-activamente basándonos en umbrales de memoria (`Utilization`).
4. **Alta Disponibilidad (`maxUnavailable` y `replicas`):** Al usar un Load Balancer con 2 pods mínimos y con la regla de Rolling Update limitando nodos indisponibles a 0, nunca causamos negación de servicio manual por mantenimientos.
