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
        --node-size=t2.micro \
        --node-count=2 \
        --node-volume-size=10 \
        --topology=public \
        --dns=public \
        --yes

    # Exportar credenciales si es la primera vez
    kops export kubecfg --admin --state=${KOPS_STATE_STORE}
fi

echo "=============================================================================="
echo " PREPARANDO DNS LOCAL PARA COMUNICACIÓN (Workaround Gossip en CI/CD) "
echo "=============================================================================="

n=0
while [ $n -le 15 ]; do
    # ¡NUEVO ENFOQUE! KOps SIEMPRE etiqueta los Security Groups del Master de manera estándar.
    # Vamos a buscar cualquier instancia corriendo que pertenezca al Security Group del Master
    # de este cluster, lo que evita depender de etiquetas impredecibles en las propias EC2.
    
    # Conseguir el ID del Security Group del Master
    SG_MASTER_ID=$(aws ec2 describe-security-groups \
        --region "$AWS_REGION" \
        --filters "Name=group-name,Values=masters.$NAME" \
        --query "SecurityGroups[0].GroupId" --output text)
        
    if [ "$SG_MASTER_ID" != "None" ] && [ -n "$SG_MASTER_ID" ]; then
        # Buscar la IP de cualquier instancia usando ese Security Group
        MASTER_IP=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --filters "Name=instance.group-id,Values=$SG_MASTER_ID" "Name=instance-state-name,Values=running" \
            --query "Reservations[*].Instances[*].PublicIpAddress" \
            --output text | awk '{print $1}')
    fi
    
    if [ -n "${MASTER_IP:-}" ] && [ "$MASTER_IP" != "None" ]; then
        echo "IP del Control Plane encontrada: $MASTER_IP"
        # Limpiar entradas antiguas en hosts por seguridad en el mismo runner
        sudo sed -i "/api\.$NAME/d" /etc/hosts || true
        # Agregar al hosts del runner para que resuelva localmente api.guillermo.k8s.local
        echo "$MASTER_IP api.$NAME" | sudo tee -a /etc/hosts
        
        # Opcional (pero muy recomendado en pipelines): Esperar a que la API responda
        echo "Validando conexión a la API Kubernetes..."
        for j in {1..30}; do
          if curl -k -s https://api.$NAME/version > /dev/null; then
             echo "¡API de Kubernetes responde en https://api.$NAME!"
             break
          fi
          echo "La API aún no levanta, esperando 10s..."
          sleep 10
        done
        break
    else
        echo "Aún no hay IP pública asignada, reintentando en 10s..."
        sleep 10
        n=$((n+1))
    fi
done

echo "=============================================================================="
echo " PROCESO COMPLETADO. Validable con: kops validate cluster"
echo "=============================================================================="
