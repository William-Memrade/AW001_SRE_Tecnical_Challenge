#!/bin/bash
set -e

# ==============================================================================
# Script para aprovisionar un cluster de Kubernetes en AWS usando KOps
# ==============================================================================

# Variables (Modificar según configuración de AWS)
#export NAME="kops-memrade.com"         # Nombre del cluster 
export KOPS_STATE_STORE="s3://kops-s3-memrade"
export AWS_REGION="us-east-2"
export ZONES="us-east-2a"

echo "1. Crear el bucket en S3 para almacenar el estado de KOps"
aws s3api create-bucket \
    --bucket kops-s3-memrade \
    --region $AWS_REGION

echo "Habilitar versionado en el bucket de S3 (Recomendado para respaldos)"
aws s3api put-bucket-versioning \
    --bucket kops-s3-memrade \
    --versioning-configuration Status=Enabled

# Nota: Antes de ejecutar, asegúrate de tener configurado tu dominio en Route53 
# o usar un cluster basado en gossip (terminando el NAME en .k8s.local)
# Para desarrollo rápido sin dominio registrado, cambiamos NAME a guillermo.k8s.local
export NAME="guillermo.k8s.local"

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
