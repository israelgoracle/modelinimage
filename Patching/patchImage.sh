#!/usr/bin/env sh
# 
# Script para aplicar parches a la imagen base de WebLogic usando WebLogic Image Tool
# Uso: ./03-patchearImagenBase.sh <patch_id_1> [patch_id_2] [patch_id_n]
# Ejemplo: ./03-patchearImagenBase.sh 35648110 35542828
# 
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under The Universal Permissive License (UPL), Version 1.0
# 

################################################################################
# Validar argumentos
################################################################################

if [ $# -eq 0 ]; then
    echo "Error: Debe proporcionar al menos un Patch ID"
    echo "Uso: $0 <patch_id_1> [patch_id_2] [patch_id_n]"
    echo "Ejemplo: $0 35648110 35542828"
    exit 1
fi

################################################################################
# Variables de configuración
################################################################################

IMAGE_BUILDER_EXE="/usr/bin/docker"
IMAGETOOL_SCRIPT="/home/opc/wkt/weblogic-tools/weblogic-image-tool-1.16.2/imagetool/bin/imagetool.sh"

# Imagen base de Oracle Container Registry
BASE_IMAGE="container-registry.oracle.com/middleware/weblogic:14.1.2.0-generic-jdk17-ol8"

# Directorio donde están los parches descargados
PATCHES_DIR="/home/opc/wkt/WKT/Patching"

# Credenciales Oracle Support (para descargar parches automáticamente - opcional)
ORACLE_SUPPORT_USER=""
ORACLE_SUPPORT_PASSWORD=""

# Credenciales OCIR
IMAGE_REGISTRY_HOST="mad.ocir.io"
IMAGE_REGISTRY_PUSH_USER="axojlwfywuhi/israel.gutierrez@oracle.com"
IMAGE_REGISTRY_PUSH_PASS="L>wTBGPs5QPnF(8wkbbq"

# Opciones adicionales
ALWAYS_PULL_BASE_IMAGE="true"
JAVA_HOME="/usr/lib/jvm/java-11-openjdk"

#Autenticacin Registry de Oracle
ORACLE_REGISTRY="container-registry.oracle.com"
ORACLE_REGISTRY_USER="israel.gutierrez@oracle.com"
ORACLE_REGISTRY_PASS="C15LldaT+2FbJsSQOLafL"

echo "Iniciando sesión en ${ORACLE_REGISTRY}..."
if ! echo "${ORACLE_REGISTRY_PASS}" | ${IMAGE_BUILDER_EXE} login \
    --username ${ORACLE_REGISTRY_USER} \
    --password-stdin ${ORACLE_REGISTRY}; then
    echo "Error: Fallo al iniciar sesión en ${ORACLE_REGISTRY}">&2
    echo "Necesita una cuenta en Oracle Container Registry para descargar imágenes de WebLogic"
    exit 1
fi

echo "Login exitoso en Oracle Container Registry"
echo ""

################################################################################
# Procesamiento de parches
################################################################################

if [ "$JAVA_HOME" != "" ]; then
    export JAVA_HOME
fi

# Construir lista de parches separados por coma
PATCH_LIST=""
PATCH_TAG=""

for PATCH_ID in "$@"
do
    # Determinar el archivo en el directorio de parches
    PATCH_FILE=$(ls ${PATCHES_DIR}/p${PATCH_ID}_*.zip 2>/dev/null | head -1)
    if [ -z "${PATCH_FILE}" ]; then
        echo "ERROR: Parche p${PATCH_ID}_*.zip no encontrado en ${PATCHES_DIR}"
        echo "Descargue el parche desde My Oracle Support y colóquelo en ${PATCHES_DIR}"
        exit 1
    fi

    # Extraer release de nombre del archivo, ejemplo: p37650720_141200_Generic.zip → 14.1.2.0.0
    # Asumimos convención _141200_ = 14.1.2.0.0
    RELEASE_VERSION=14.1.2.0.0

    # Formar patch ID completo
    PATCH_ID_FULL="${PATCH_ID}_${RELEASE_VERSION}"

    echo "Procesando parche: ${PATCH_ID_FULL}"
    echo "  Archivo local: ${PATCH_FILE}"

    # Añadir al cache si no existe
    if ! "${IMAGETOOL_SCRIPT}" cache addPatch --patchId "${PATCH_ID_FULL}" --path "${PATCH_FILE}"; then
        echo "  Advertencia: No se pudo añadir parche ${PATCH_ID_FULL} al cache (ya puede existir)"
    fi

    # Construir lista de parches para imagetool update
    if [ -z "${PATCH_LIST}" ]; then
        PATCH_LIST="${PATCH_ID_FULL}"
        PATCH_TAG="p${PATCH_ID}"
    else
        PATCH_LIST="${PATCH_LIST},${PATCH_ID_FULL}"
        PATCH_TAG="${PATCH_TAG}-p${PATCH_ID}"
    fi
done

echo ""
echo "Lista de parches a aplicar: ${PATCH_LIST}"

# Generar tag de la nueva imagen
PATCHED_IMAGE="mad.ocir.io/axojlwfywuhi/oke/weblogic:14.1.2.0.0-${PATCH_TAG}"

echo "Imagen base: ${BASE_IMAGE}"
echo "Imagen destino: ${PATCHED_IMAGE}"
echo ""

################################################################################
# Construir argumentos para imagetool update
################################################################################

IMAGETOOL_ARGS="update --fromImage=\"${BASE_IMAGE}\" --tag=\"${PATCHED_IMAGE}\" --patches=\"${PATCH_LIST}\""

if [ "${ALWAYS_PULL_BASE_IMAGE}" = "true" ]; then
    IMAGETOOL_ARGS="${IMAGETOOL_ARGS} --pull"
fi

# Si tiene credenciales de Oracle Support para descargar parches
#if [ "${ORACLE_SUPPORT_USER}" != "" ] && [ "${ORACLE_SUPPORT_PASSWORD}" != "" ]; then
#    IMAGETOOL_ARGS="${IMAGETOOL_ARGS} --user=\"${ORACLE_SUPPORT_USER}\" --passwordEnv=ORACLE_SUPPORT_PASSWORD"
#    export ORACLE_SUPPORT_PASSWORD
#fi

################################################################################
# Actualizar imagen con parches
################################################################################

echo "Ejecutando: imagetool ${IMAGETOOL_ARGS}"
echo ""

if ! "${IMAGETOOL_SCRIPT}" ${IMAGETOOL_ARGS}; then
    echo "Error: Fallo al crear imagen parcheada ${PATCHED_IMAGE}">&2
    exit 1
fi

echo ""
echo "Imagen parcheada creada exitosamente: ${PATCHED_IMAGE}"
echo ""

################################################################################
# Push a OCIR
################################################################################

# Login a OCIR
echo "Iniciando sesión en ${IMAGE_REGISTRY_HOST}..."
if ! echo "${IMAGE_REGISTRY_PUSH_PASS}" | ${IMAGE_BUILDER_EXE} login \
    --username ${IMAGE_REGISTRY_PUSH_USER} \
    --password-stdin ${IMAGE_REGISTRY_HOST}; then
    echo "Error: Fallo al iniciar sesión en ${IMAGE_REGISTRY_HOST}">&2
    exit 1
fi

# Push de la imagen
echo "Subiendo imagen a OCIR..."
if ! "${IMAGE_BUILDER_EXE}" push ${PATCHED_IMAGE}; then
    echo "Error: Fallo al subir imagen ${PATCHED_IMAGE}">&2
    exit 1
fi

echo ""
echo "=========================================="
echo "Proceso completado exitosamente"
echo "=========================================="
echo ""
echo "Imagen parcheada disponible en: ${PATCHED_IMAGE}"
echo ""
echo "Para usar esta imagen en sus dominios, actualice el campo 'spec.image' en el Domain YAML:"
echo ""
echo "  spec:"
echo "    image: \"${PATCHED_IMAGE}\""
echo "    imagePullSecrets:"
echo "      - name: ocir-secret"
echo "    configuration:"
echo "      model:"
echo "        auxiliaryImages:"
echo "          - image: \"mad.ocir.io/axojlwfywuhi/oke/telco-wcv2:v1.1\"  # Su imagen auxiliar actual"
echo ""
echo "Parches aplicados: ${PATCH_LIST}"
echo ""
