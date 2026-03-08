#!/usr/bin/env bash
set -euo pipefail

echo "=============================================================================="
echo " AWS - Gestionando el cluster: $CLUSTER_NAME"
echo "=============================================================================="

# 1. Validar si existe el Bucket para no fallar
if ! aws s3api head-bucket --bucket "${KOPS_STORAGE_BUCKET}" 2>/dev/null; then
    echo "Creando Bucket S3: ${KOPS_STORAGE_BUCKET}..."
    aws s3api create-bucket --bucket "${KOPS_STORAGE_BUCKET}" --region "${AWS_REGION}"
    aws s3api put-bucket-versioning --bucket "${KOPS_STORAGE_BUCKET}" --versioning-configuration Status=Enabled
fi

# 2. Validar si el clúster ya existe
if kops get cluster --name "$CLUSTER_NAME" --state "s3://$KOPS_STORAGE_BUCKET" > /dev/null 2>&1; then
    echo "=========================================="
    echo "El clúster ya existe. Ejecutando UPDATE..."
    echo "=========================================="
    
    kops update cluster --name "$CLUSTER_NAME" --state "s3://$KOPS_STORAGE_BUCKET" --yes

else
    echo "=========================================="
    echo "El clúster NO existe. Ejecutando CREATE..."
    echo "=========================================="
    
    # Hemos agregado la restricción de los 10GB de master/nodes para Free Tier 
    # y adaptado tu template. 
    kops create cluster \
        --name "$CLUSTER_NAME" \
        --state "s3://$KOPS_STORAGE_BUCKET" \
        --zones "$AWS_ZONES" \
        --control-plane-size "t2.micro" \
        --master-volume-size 10 \
        --node-size "t2.micro" \
        --node-count 2 \
        --node-volume-size 10 \
        --networking calico \
        --container-runtime containerd \
        --topology public \
        --dns public \
        --yes
fi

echo "Esperando validación completa de KOps (esto tardará unos minutos)..."
kops validate cluster --name "$CLUSTER_NAME" --state "s3://$KOPS_STORAGE_BUCKET" --wait 15m

echo "Exportando kubeconfig..."
kops export kubeconfig --name "$CLUSTER_NAME" --state "s3://$KOPS_STORAGE_BUCKET" --admin

echo "Validando nodos..."
kubectl get nodes -o wide
