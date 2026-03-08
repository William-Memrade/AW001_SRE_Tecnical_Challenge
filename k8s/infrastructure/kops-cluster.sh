#!/bin/bash
set -e

# ==============================================================================
# Script para aprovisionar un cluster de Kubernetes en AWS usando KOps
# ==============================================================================

# Free Trail no me permitio configurar dominio con Route 53
# Por lo que usamos un cluster basado en gossip (terminando el NAME en .k8s.local)
export NAME="${EKS_CLUSTER_NAME}"
export KOPS_STORAGE_BUCKET="${STORAGE_BUCKET}"
export AWS_REGION="${AWS_REGION}"
export ZONES="${AWS_ZONES}"

echo "1. Crear el bucket en S3 para almacenar el estado de KOps"
aws s3api create-bucket \
    --bucket $KOPS_STORAGE_BUCKET \
    --region $AWS_REGION

echo "Habilitar versionado en el bucket de S3 (Recomendado para respaldos)"
aws s3api put-bucket-versioning \
    --bucket $KOPS_STORAGE_BUCKET \
    --versioning-configuration Status=Enabled

echo "2. Crear la configuración del cluster (solo definición)"
kops create cluster \
    --name=${NAME} \
    --cloud=aws \
    --zones=${ZONES} \
    --node-count=2 \
    --node-size=t2.micro \
    --master-size=t2.micro \
    --topology=public \
    --dns=private

echo "3. Aplicar los cambios y crear físicamente los recursos en AWS"
kops update cluster --name ${NAME} --yes --admin

echo "4. Validar el cluster"
echo "La validación tomará unos minutos mientras inician las instancias EC2..."
kops validate cluster --wait 10m

echo "Exportar KUBECONFIG a la terminal actual (por lo general KOps lo actualiza automáticamente en ~/.kube/config)"
kops export kubecfg --admin
