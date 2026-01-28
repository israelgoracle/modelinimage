#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESPLIEGUE_DIR="${SCRIPT_DIR}/despliegue"
APP_SOURCE="${DESPLIEGUE_DIR}/holamundo-app"
WLSDEPLOY_DIR="${DESPLIEGUE_DIR}/wlsdeploy"
APPLICATIONS_DIR="${WLSDEPLOY_DIR}/applications"
MODEL_FILE="${DESPLIEGUE_DIR}/model.yaml"

java -version

echo "======================================"
echo "Despliegue holamundo-app en WCV2"
echo "======================================"

# Compilar la aplicación
echo ""
echo "[1/4] Compilando aplicación..."
cd "${APP_SOURCE}"
mvn clean package -DskipTests

APP_WAR=$(find target -name "*.war" | head -1)
APP_NAME=$(basename "${APP_WAR}")
echo "WAR generado: ${APP_NAME}"

# Crear estructura wlsdeploy si no existe
echo ""
echo "[2/4] Preparando estructura wlsdeploy..."
mkdir -p "${APPLICATIONS_DIR}"

# Copiar WAR
cp "${APP_WAR}" "${APPLICATIONS_DIR}/"
echo "Copiado ${APP_NAME} a ${APPLICATIONS_DIR}/"

# Crear archive.zip
echo ""
echo "[3/4] Creando archive.zip..."
cd "${DESPLIEGUE_DIR}"
rm -f archive.zip
zip -r archive.zip wlsdeploy/
echo "Creado ${DESPLIEGUE_DIR}/archive.zip"

# Modificar model.yaml
echo ""
echo "[4/4] Actualizando model.yaml..."
cp "${MODEL_FILE}" "${MODEL_FILE}.bak"

APP_NAME_NO_EXT="${APP_NAME%.war}"

# Añadir aplicación dentro de appDeployments.Application usando awk
awk -v app="${APP_NAME_NO_EXT}" -v war="${APP_NAME}" '
/^    Application:/ {
    print
    print "        " app ":"
    print "            SourcePath: wlsdeploy/applications/" war
    print "            ModuleType: war"
    print "            Target: WCV2wlnCOV3"
    next
}
{print}
' "${MODEL_FILE}" > "${MODEL_FILE}.tmp" && mv "${MODEL_FILE}.tmp" "${MODEL_FILE}"

echo ""
echo "======================================"
echo "Completado: ${APP_NAME} añadido"
echo "======================================"
