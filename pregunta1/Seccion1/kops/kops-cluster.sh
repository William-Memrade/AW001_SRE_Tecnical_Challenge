#!/usr/bin/env bash
set -euo pipefail

echo "=============================================================================="
echo " AWS - Gestionando el cluster: $KOPS_CLUSTER_NAME"
echo "=============================================================================="

# 1. Validar si existe el Bucket para no fallar
if ! aws s3api head-bucket --bucket "${KOPS_STORAGE_BUCKET}" 2>/dev/null; then
    echo "Creando Bucket S3: ${KOPS_STORAGE_BUCKET}..."
    aws s3api create-bucket --bucket "${KOPS_STORAGE_BUCKET}" --region "${AWS_REGION}"
    aws s3api put-bucket-versioning --bucket "${KOPS_STORAGE_BUCKET}" --versioning-configuration Status=Enabled
fi

# 2. Validar si el clúster ya existe
if kops get cluster --name "$KOPS_CLUSTER_NAME" --state "s3://$KOPS_STORAGE_BUCKET" > /dev/null 2>&1; then
    echo "=========================================="
    echo "El clúster ya existe. Ejecutando UPDATE..."
    echo "=========================================="
    
    kops get cluster --name "$KOPS_CLUSTER_NAME" --state "s3://$KOPS_STORAGE_BUCKET" -o yaml > cluster-config-update.yaml
    
    pip3 install pyyaml || true
    python3 $(dirname "$0")/remove_kops_lb.py cluster-config-update.yaml
    
    kops replace -f cluster-config-update.yaml --state "s3://$KOPS_STORAGE_BUCKET" --force
    kops update cluster --name "$KOPS_CLUSTER_NAME" --state "s3://$KOPS_STORAGE_BUCKET" --yes --admin

else
    echo "=========================================="
    echo "El clúster NO existe. Ejecutando CREATE..."
    echo "=========================================="

    kops create cluster \
        --name "$KOPS_CLUSTER_NAME" \
        --state "s3://$KOPS_STORAGE_BUCKET" \
        --zones "$AWS_ZONES" \
        --control-plane-size "t3.small" \
        --control-plane-volume-size 10 \
        --node-size "t3.small" \
        --node-count 2 \
        --node-volume-size 10 \
        --networking calico \
        --topology public \
        --dns public \
        --dry-run -o yaml > cluster-config.yaml

    echo "Removiendo el NLB del API Server para AWS Free Tier..."

    pip3 install pyyaml || true
    python3 $(dirname "$0")/remove_kops_lb.py cluster-config.yaml

    echo "Aplicando configuración modificada..."
    kops replace -f cluster-config.yaml --state "s3://$KOPS_STORAGE_BUCKET" --force
    kops update cluster --name "$KOPS_CLUSTER_NAME" --state "s3://$KOPS_STORAGE_BUCKET" --yes --admin
fi

echo "=============================================================================="
echo " INYECTANDO DNS LOCAL PARA COMUNICACIÓN GOSSIP "
echo "=============================================================================="
n=0
while [ $n -le 15 ]; do
    # Búsqueda a prueba de fallas usando Security Groups
    SG_MASTER_ID=$(aws ec2 describe-security-groups \
        --region "$AWS_REGION" \
        --filters "Name=group-name,Values=masters.$KOPS_CLUSTER_NAME" \
        --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")
        
    if [ "$SG_MASTER_ID" != "None" ] && [ -n "$SG_MASTER_ID" ]; then
        MASTER_IP=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --filters "Name=instance.group-id,Values=$SG_MASTER_ID" "Name=instance-state-name,Values=running" \
            --query "Reservations[*].Instances[*].PublicIpAddress" \
            --output text | awk '{print $1}')
            
        if [ -n "${MASTER_IP:-}" ] && [ "$MASTER_IP" != "None" ]; then
            echo "IP del Control Plane encontrada: $MASTER_IP"
            sudo sed -i "/api\.$KOPS_CLUSTER_NAME/d" /etc/hosts || true
            echo "$MASTER_IP api.$KOPS_CLUSTER_NAME" | sudo tee -a /etc/hosts
            break
        fi
    fi
    
    echo "Aún no hay IP pública asignada, reintentando en 10s..."
    sleep 10
    n=$((n+1))
done

echo "Esperando validación completa de KOps (esto tardará unos minutos)..."
kops validate cluster --name "$KOPS_CLUSTER_NAME" --state "s3://$KOPS_STORAGE_BUCKET" --wait 15m

echo "Exportando kubeconfig..."
kops export kubeconfig --name "$KOPS_CLUSTER_NAME" --state "s3://$KOPS_STORAGE_BUCKET" --admin

echo "Validando nodos..."
kubectl get nodes -o wide
