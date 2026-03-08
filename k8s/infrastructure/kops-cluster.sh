#!/bin/bash
set -e

# ==============================================================================
# Script para aprovisionar un cluster de Kubernetes en AWS usando KOps
# ==============================================================================

# Free Trail no me permitio configurar dominio con Route 53
# Por lo que usamos un cluster basado en gossip (terminando el NAME en .k8s.local)
export ZONES="${AWS_ZONES}"
export AWS_REGION="${AWS_REGION}"
export NAME="${EKS_CLUSTER_NAME}"
export KOPS_STORAGE_BUCKET="${STORAGE_BUCKET}"
export KOPS_STATE_STORE="s3://${KOPS_STORAGE_BUCKET}"

# Validar si el bucket S3 ya existe
if ! aws s3api head-bucket --bucket "$KOPS_STORAGE_BUCKET" 2>/dev/null; then
    echo "1. Crear el bucket en S3 para almacenar el estado de KOps"
    aws s3api create-bucket \
        --bucket $KOPS_STORAGE_BUCKET \
        --region $AWS_REGION

    echo "Habilitar versionado en el bucket de S3 (Recomendado para respaldos)"
    aws s3api put-bucket-versioning \
        --bucket $KOPS_STORAGE_BUCKET \
        --versioning-configuration Status=Enabled
else
    echo "1. Bucket S3 $KOPS_STORAGE_BUCKET ya existe, omitiendo creación."
fi


echo "2. Crear la configuración del cluster"
if ! kops get cluster --name "${NAME}" --state="${KOPS_STATE_STORE}" > /dev/null 2>&1; then
    echo "2.1 Generando manifiesto (dry-run) sin aplicar..."
    kops create cluster \
        --name=${NAME} \
        --state=${KOPS_STATE_STORE} \
        --zones=${ZONES} \
        --control-plane-size=t2.micro \
        --node-count=2 \
        --node-size=t2.micro \
        --topology=public \
        --dns=public \
        --dry-run -o yaml > cluster-config.yaml
else
    echo "2.1 La configuración ya existe, exportándola para asegurar que el LoadBalancer está desactivado..."
    kops get cluster --name "${NAME}" --state="${KOPS_STATE_STORE}" -o yaml > cluster-config.yaml
fi

echo "2.2 Eliminando dependencia del LoadBalancer en el API Server..."
python3 $(dirname "$0")/remove_kops_lb.py cluster-config.yaml

echo "2.3 Actualizando definición del clúster..."
kops replace -f cluster-config.yaml --state=${KOPS_STATE_STORE} --force

echo "3. Aplicar los cambios y crear físicamente los recursos en AWS"
kops update cluster --name ${NAME} --yes --admin

echo "4. Preparando DNS local para la comunicación directa con el Master (Gossip workaround)"
echo "Buscando IP pública del Control Plane..."

n=0
while [ $n -le 15 ]; do
    # Buscar por tag de KOps (puede ser control-plane o master dependiendo de la versión)
    MASTER_IP=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=tag:KubernetesCluster,Values=$NAME" "Name=instance-state-name,Values=running" "Name=tag:k8s.io/role/control-plane,Values=1" \
        --query "Reservations[*].Instances[*].PublicIpAddress" \
        --output text | awk '{print $1}')
    
    # Fallback si usa la etiqueta antigua "master"
    if [ -z "$MASTER_IP" ] || [ "$MASTER_IP" == "None" ]; then
        MASTER_IP=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --filters "Name=tag:KubernetesCluster,Values=$NAME" "Name=instance-state-name,Values=running" "Name=tag:k8s.io/role/master,Values=1" \
            --query "Reservations[*].Instances[*].PublicIpAddress" \
            --output text | awk '{print $1}')
    fi
    
    if [ -n "$MASTER_IP" ] && [ "$MASTER_IP" != "None" ]; then
        echo "IP del Control Plane encontrada: $MASTER_IP"
        # Agregar al hosts del runner para que resuelva api.guillermo.k8s.local
        echo "$MASTER_IP api.$NAME" | sudo tee -a /etc/hosts
        break
    else
        echo "Aún no hay IP pública asignada, reintentando en 10s..."
        sleep 10
        n=$((n+1))
    fi
done

echo "5. Validar el cluster"
echo "La validación tomará unos minutos mientras inician las instancias EC2 y los servicios de Kubernetes..."
kops validate cluster --wait 10m

echo "Exportar KUBECONFIG a la terminal actual (por lo general KOps lo actualiza automáticamente en ~/.kube/config)"
kops export kubecfg --admin
