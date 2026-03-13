#!/bin/bash
set -e

# ==============================================================================
# Script para DESPLEGAR recursos estáticos de Nginx en Kubernetes
# ==============================================================================

echo "=============================================================================="
echo " Aplicando Manifiestos al Clúster Kubernetes"
echo "=============================================================================="

# Directorio de manifiestos (funciona relativo a donde está el pipeline)
MANIFEST_DIR="$(dirname "$0")/../kubernetes"

# 1. Crear el namespace primero (Evita errores de dependencia)
echo "1. Configurando Namespace..."
kubectl apply -f "${MANIFEST_DIR}/namespace.yaml"

# 2. Desplegar ConfigMap (Dependencia de volumen de Nginx)
echo "2. Creando ConfigMap (index.html personalizado)..."
kubectl apply -f "${MANIFEST_DIR}/configmap.yaml"

# 3. Desplegar Nginx
echo "3. Levantando Deployment de Nginx..."
kubectl apply -f "${MANIFEST_DIR}/deployment.yaml"

# 4. Exponer Servicio (LoadBalancer)
echo "4. Exponiendo Nginx como LoadBalancer..."
kubectl apply -f "${MANIFEST_DIR}/service.yaml"

# 5. Aplicar Horizontal Pod Autoscaler (HPA)
echo "5. Configurando Autoescalado (HPA)..."
kubectl apply -f "${MANIFEST_DIR}/hpa.yaml"

echo "=============================================================================="
echo " MANIFIESTOS DESPLEGADOS EXITOSAMENTE "
echo "=============================================================================="
