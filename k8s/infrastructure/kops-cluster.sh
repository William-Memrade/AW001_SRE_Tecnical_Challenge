#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script para Aprovisionar o Actualizar cluster de Kubernetes en AWS usando KOps
# ==============================================================================

export ZONES="${AWS_ZONES:-us-east-1a}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
# Usamos el nombre local de EKS_CLUSTER_NAME para gossip (ej. cluster.k8s.local)
export NAME="${EKS_CLUSTER_NAME}"
export KOPS_STORAGE_BUCKET="${KOPS_STORAGE_BUCKET}"
export KOPS_STATE_STORE="s3://${KOPS_STORAGE_BUCKET}"

if [[ -z "${KOPS_STATE_STORE:-}" ]]; then
  echo "KOPS_STATE_STORE no definido"
  exit 1
fi

echo "=============================================================================="
echo " AWS - Gestionando el cluster: $NAME"
echo "=============================================================================="

# 1. Validar/Crear Bucket S3
if ! aws s3api head-bucket --bucket "$KOPS_STORAGE_BUCKET" 2>/dev/null; then
    echo "1. Crear el bucket en S3 para almacenar el estado de KOps..."
    aws s3api create-bucket \
        --bucket $KOPS_STORAGE_BUCKET \
        --region $AWS_REGION

    aws s3api put-bucket-versioning \
        --bucket $KOPS_STORAGE_BUCKET \
        --versioning-configuration Status=Enabled
else
    echo "1. Bucket S3 $KOPS_STORAGE_BUCKET listo."
fi

echo "2. Validando estado del clúster..."

if kops get cluster --name "${NAME}" --state="${KOPS_STATE_STORE}" > /dev/null 2>&1; then
    echo "=========================================="
    echo "El clúster ya existe. Ejecutando UPDATE..."
    echo "=========================================="
    
    kops update cluster --name "${NAME}" --state="${KOPS_STATE_STORE}" --yes --admin
    echo "Aplicando Rolling Update si hay cambios en los nodos..."
    # kops rolling-update cluster --name ${NAME} --state=${KOPS_STATE_STORE} --yes --fail-on-validate-error="false"
else
    echo "=========================================="
    echo "El clúster NO existe. Ejecutando CREATE..."
    echo "=========================================="
    
    kops create cluster \
        --name="${NAME}" \
        --state="${KOPS_STATE_STORE}" \
        --zones="${ZONES}" \
        --master-size=t2.micro \
        --master-volume-size=10 \
        --node-count=2 \
        --node-size=t2.micro \
        --node-volume-size=10 \
        --topology=public \
        --dns=public \
        --yes

    # Exportar credenciales si es la primera vez
    kops export kubecfg --admin --state=${KOPS_STATE_STORE}
fi

echo "=============================================================================="
echo " PROCESO COMPLETADO. Validar estado con: kops validate cluster"
echo "=============================================================================="
