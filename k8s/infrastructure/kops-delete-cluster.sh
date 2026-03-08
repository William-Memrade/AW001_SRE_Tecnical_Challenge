#!/bin/bash
set -e

# ==============================================================================
# Script para ELIMINAR el cluster de Kubernetes en AWS usando KOps
# y el bucket S3 asociado para evitar costos en AWS.
# ==============================================================================

export AWS_REGION="${AWS_REGION:-us-east-1}"
export NAME="${EKS_CLUSTER_NAME}"
export KOPS_STORAGE_BUCKET="${KOPS_STORAGE_BUCKET}"
export KOPS_STATE_STORE="${KOPS_STORAGE_BUCKET}"

echo "=============================================================================="
echo " AWS Free Tier - Eliminando el cluster: $NAME"
echo "=============================================================================="

# 1. Eliminar el cluster de KOps
if kops get cluster --name "${NAME}" --state="${KOPS_STATE_STORE}" > /dev/null 2>&1; then
    echo "1. Eliminando el cluster de KOps (EC2, VPC, EBS, etc.)..."
    # Primero hacemos un dry-run implícito al listar y luego borramos con --yes
    kops delete cluster --name ${NAME} --state=${KOPS_STATE_STORE} --yes
    echo "Cluster de Kubernetes eliminado correctamente."
else
    echo "1. El cluster $NAME no fue encontrado en KOps o ya fue eliminado."
fi

# 2. Eliminar el bucket S3 (opcional, pero sugerido para evitar gastos de almacenamiento)
echo "2. Revisando bucket S3 del estado de KOps..."
if aws s3api head-bucket --bucket "$KOPS_STORAGE_BUCKET" 2>/dev/null; then
    echo "   Se encontró el bucket S3: $KOPS_STORAGE_BUCKET"
    
    # Preguntarle al usuario antes de borrar el bucket S3, ya que esto pierde 
    # definitivamente el historial o config del cluster
    read -p "   ¿Quieres eliminar también el bucket S3 ($KOPS_STORAGE_BUCKET) y todo su contenido? [y/N]: " delete_bucket
    
    if [[ "$delete_bucket" =~ ^[Yy]$ ]]; then
        echo "   Vaciando el bucket (incluyendo versiones si las hay)..."
        
        # Como habilitamos el versionado al crearlo, tenemos que borrar todo el historial primero:
        aws s3api delete-objects \
            --bucket $KOPS_STORAGE_BUCKET \
            --delete "$(aws s3api list-object-versions \
                --bucket $KOPS_STORAGE_BUCKET \
                --output=json \
                --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" || true
        
        # Eliminar los 'DeleteMarkers' también
        aws s3api delete-objects \
            --bucket $KOPS_STORAGE_BUCKET \
            --delete "$(aws s3api list-object-versions \
                --bucket $KOPS_STORAGE_BUCKET \
                --output=json \
                --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" || true
                
        # Por último eliminar el bucket:
        aws s3 rb $KOPS_STORAGE_BUCKET --force
        echo "   Bucket S3 eliminado correctamente."
    else
        echo "   El bucket S3 se mantendrá intacto."
    fi
else
    echo "   El bucket S3 ya no existe o no hay acceso."
fi

# 3. Limpiar archivo hosts local
echo "3. Limpiando entradas locales del proxy de /etc/hosts..."
# Remueve cualquier línea que contenga `api.$NAME`
sudo sed -i "/api\.$NAME/d" /etc/hosts || true

echo "=============================================================================="
echo " PROCESO DE ELIMINACIÓN COMPLETADO."
echo "=============================================================================="
