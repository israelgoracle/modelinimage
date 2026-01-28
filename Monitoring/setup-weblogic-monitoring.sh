#!/bin/bash
#
# Script completo para configurar WebLogic Monitoring con Prometheus 3.x
# 
# Descripción: Configura monitorización completa de WJMS en Prometheus/Grafana
#              usando additionalScrapeConfigs con fallback_scrape_protocol
#              (necesario para Prometheus 3.x debido a bug en WebLogic Exporter)
#
# Requisitos previos:
#   - Domain WJMS desplegado con monitoringExporter sidecar
#   - Prometheus Operator (kube-prometheus-stack) instalado
#   - Prometheus 3.x
#

set -e

echo "=================================================================="
echo "Configuración de WebLogic Monitoring Exporter para Prometheus 3.x"
echo "=================================================================="

# Variables
NAMESPACE_WJMS="wjms-ns"
NAMESPACE_MONITORING="monitoring"
PROMETHEUS_NAME="kube-prometheus-stack-prometheus"

echo ""
echo "Configuración:"
echo "  - Namespace WebLogic:  ${NAMESPACE_WJMS}"
echo "  - Namespace Prometheus: ${NAMESPACE_MONITORING}"
echo "  - Prometheus name:     ${PROMETHEUS_NAME}"
echo ""

# ============================================================
# PASO 1: Crear Secret con credenciales de autenticación
# ============================================================
echo "[1/6] Creando Secret con credenciales de autenticación..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: wjms-exporter-auth
  namespace: ${NAMESPACE_WJMS}
type: Opaque
stringData:
  username: weblogic
  password: welcome1
EOF

# ============================================================
# PASO 2: Crear Service para exponer puerto 8080 del sidecar
# ============================================================
echo ""
echo "[2/6] Creando Service para exponer métricas..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: wjms-exporter
  namespace: ${NAMESPACE_WJMS}
  labels:
    weblogic.domainUID: wjms
    app: weblogic-monitoring-exporter
spec:
  type: ClusterIP
  ports:
  - name: metrics
    port: 8080
    targetPort: 8080
    protocol: TCP
  selector:
    weblogic.domainUID: wjms
EOF

# ============================================================
# PASO 3: Eliminar ServiceMonitor si existe
# ============================================================
echo ""
echo "[3/6] Eliminando ServiceMonitor (incompatible con Prometheus 3.x)..."
kubectl delete servicemonitor -n ${NAMESPACE_WJMS} wjms-weblogic-exporter --ignore-not-found=true

# ============================================================
# PASO 4: Crear Secret con additionalScrapeConfigs
# ============================================================
echo ""
echo "[4/6] Creando Secret con configuración de scrape para Prometheus 3.x..."

# Obtener IPs de los pods de WebLogic
ADMIN_IP=$(kubectl get pod -n ${NAMESPACE_WJMS} -l weblogic.serverName=wjmswladmin0 -o jsonpath='{.items[0].status.podIP}')
COCO_IP=$(kubectl get pod -n ${NAMESPACE_WJMS} -l weblogic.clusterName=WJMSjmsCOCO -o jsonpath='{.items[0].status.podIP}')
WJMS_IP=$(kubectl get pod -n ${NAMESPACE_WJMS} -l weblogic.clusterName=WJMSjmsWJMS -o jsonpath='{.items[0].status.podIP}')

echo "  - AdminServer IP:  ${ADMIN_IP}"
echo "  - Cluster COCO IP: ${COCO_IP}"
echo "  - Cluster WJMS IP: ${WJMS_IP}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: additional-scrape-configs
  namespace: ${NAMESPACE_MONITORING}
stringData:
  prometheus-additional.yaml: |
    - job_name: 'wjms-weblogic-exporter'
      scrape_interval: 30s
      metrics_path: /metrics
      # CRÍTICO: fallback_scrape_protocol es necesario para Prometheus 3.x
      # debido a que WebLogic Monitoring Exporter no envía Content-Type correcto
      fallback_scrape_protocol: "PrometheusText0.0.4"
      # Autenticación básica
      basic_auth:
        username: weblogic
        password: welcome1
      # Configuración estática de targets (IPs de los pods)
      static_configs:
        - targets:
          - '${ADMIN_IP}:8080'
          - '${COCO_IP}:8080'
          - '${WJMS_IP}:8080'
          labels:
            namespace: ${NAMESPACE_WJMS}
            domain: wjms
EOF

# ============================================================
# PASO 5: Configurar Prometheus para usar additionalScrapeConfigs
# ============================================================
echo ""
echo "[5/6] Configurando Prometheus para usar configuración adicional..."

kubectl patch prometheus -n ${NAMESPACE_MONITORING} ${PROMETHEUS_NAME} --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/additionalScrapeConfigs",
    "value": {
      "name": "additional-scrape-configs",
      "key": "prometheus-additional.yaml"
    }
  }
]' 2>/dev/null || echo "  (El campo additionalScrapeConfigs ya existe, continuando...)"

# ============================================================
# PASO 6: Forzar recarga de Prometheus
# ============================================================
echo ""
echo "[6/6] Forzando reinicio de Prometheus para aplicar cambios..."

kubectl delete pod -n ${NAMESPACE_MONITORING} prometheus-${PROMETHEUS_NAME}-0

echo "  Esperando a que Prometheus esté listo..."
kubectl wait --for=condition=ready pod -n ${NAMESPACE_MONITORING} -l app.kubernetes.io/name=prometheus --timeout=120s

echo ""
echo "=================================================================="
echo "Configuración completada exitosamente"
echo "=================================================================="
echo ""
echo "VERIFICACIONES:"
echo ""
echo "1. Ver Service y endpoints:"
echo "   kubectl get svc -n ${NAMESPACE_WJMS} wjms-exporter"
echo "   kubectl get endpoints -n ${NAMESPACE_WJMS} wjms-exporter"
echo ""
echo "2. Verificar Secret de Prometheus:"
echo "   kubectl get secret -n ${NAMESPACE_MONITORING} additional-scrape-configs"
echo ""
echo "3. Acceder a Prometheus UI:"
echo "   kubectl port-forward -n ${NAMESPACE_MONITORING} svc/${PROMETHEUS_NAME} 9090:9090"
echo "   Abrir: http://localhost:9090/targets"
echo "   Buscar: 'wjms-weblogic-exporter' (debería tener 3 endpoints UP)"
echo ""
echo "4. Probar query en Prometheus:"
echo "   Query: wls_jvm_heap_free_current"
echo "   Deberías ver métricas de los 3 servidores"
echo ""
echo "SIGUIENTE PASO:"
echo "   Configurar Grafana con dashboards de WebLogic"
echo ""
echo "NOTAS:"
echo "   - Si los pods de WebLogic se reinician, las IPs cambiarán"
echo "   - En ese caso, vuelve a ejecutar este script para actualizar las IPs"
echo "   - Alternativa: usar kubernetes_sd_configs en lugar de static_configs"
echo ""
