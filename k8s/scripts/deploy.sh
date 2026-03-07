#!/bin/bash
# ==============================================================================
# Script para desplegar la aplicación en el cluster de Kubernetes
# ==============================================================================
set -e

# Aseguramos de estar en la raíz de los archivos
cd "$(dirname "$0")/.."

echo "🚀 Iniciando despliegue de recursos en Kubernetes..."

echo "📦 1. Aplicando ConfigMap (Página web personalizada)..."
kubectl apply -f kubernetes/configmap.yaml

echo "🛠️  2. Aplicando Deployment (ReplicaSet + Pods Nginx)..."
kubectl apply -f kubernetes/deployment.yaml

echo "🌐 3. Aplicando Service LoadBalancer (Exposición externa)..."
kubectl apply -f kubernetes/service.yaml

echo "📈 4. Aplicando Horizontal Pod Autoscaler (HPA)..."
kubectl apply -f kubernetes/hpa.yaml

echo ""
echo "✅ Despliegue iniciado correctamente."
echo ""
echo "🔍 Para monitorear el progreso, puedes ejecutar:"
echo "   kubectl get pods -w"
echo "   kubectl get svc nginx-service -w"
echo "=============================================================================="
