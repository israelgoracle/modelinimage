# R
# This script uses the WebLogic Image Tool to generate a new auxiliary image
# Adapted for OCI Compute instance (Linux AMD64)
# 
# Copyright (c) 2021, 2025, Oracle and/or its affiliates.
# Licensed under The Universal Permissive License (UPL), Version 1.0
# as shown at https://oss.oracle.com/licenses/upl/.
# 

################################################################################
# Start user-defined variable section (edit as needed)                         #
################################################################################

DOCKER_BUILDKIT="0"
WLSIMG_BLDDIR="${TMPDIR:-/tmp}"
JAVA_HOME="/usr/lib/jvm/java-11-openjdk"

# No proxy needed in OCI
HTTPS_PROXY=""
NO_PROXY=""

IMAGE_BUILDER_NAME="docker"
IMAGE_BUILDER_EXE="/usr/bin/docker"
IMAGETOOL_SCRIPT="/home/opc/wkt/weblogic-tools/imagetool/bin/imagetool.sh"
IMAGE_TAG="mad.ocir.io/axojlwfywuhi/oke/telco-cohi:v1.2"
ALWAYS_PULL_BASE_IMAGE="true"

IMAGE_PUSH_REQUIRES_AUTH="true"
IMAGE_REGISTRY_HOST="mad.ocir.io"
IMAGE_REGISTRY_PUSH_USER="axojlwfywuhi/israel.gutierrez@oracle.com"
IMAGE_REGISTRY_PUSH_PASS="L>wTBGPs5QPnF(8wkbbq"

# Not needed for Oracle Container Registry
USE_LOGIN_FOR_DOCKER_HUB="false"
DOCKER_HUB_USER=""
DOCKER_HUB_PASS=""

# Update these paths to your OCI instance paths
WDT_INSTALLER="/home/opc/wkt/WKT/image/weblogic-deploy.tar.gz"
WDT_VERSION="4.3.8"

WDT_HOME=""
WDT_MODEL_HOME=""
WDT_MODEL_FILE="/home/opc/wkt/WKT/COHI/COHI-models/model.yaml"
WDT_VARIABLE_FILE="/home/opc/wkt/WKT/COHI/COHI-models/variables.properties"
WDT_ARCHIVE_FILE="/home/opc/wkt/WKT/COHI/COHI-models/archive.zip"

TARGET=""
CHOWN=""
BUILD_NETWORK=""

################################################################################
# End user-defined variable section (no edits needed below this line)          #
################################################################################

if [ "$DOCKER_BUILDKIT" != "" ]; then
    export DOCKER_BUILDKIT
fi

if [ "$WLSIMG_BLDDIR" != "" ]; then
    export WLSIMG_BLDDIR
fi

if [ "$JAVA_HOME" != "" ]; then
    export JAVA_HOME
fi

# Verify imagetool exists
if [ ! -f "${IMAGETOOL_SCRIPT}" ]; then
    echo "ERROR: WebLogic Image Tool not found at ${IMAGETOOL_SCRIPT}">&2
    echo "Please run install-weblogic-tools.sh first">&2
    exit 1
fi

# Verify WDT installer exists
if [ ! -f "${WDT_INSTALLER}" ]; then
    echo "ERROR: WDT installer not found at ${WDT_INSTALLER}">&2
    echo "Please download WebLogic Deploy Tool from:">&2
    echo "https://github.com/oracle/weblogic-deploy-tooling/releases">&2
    exit 1
fi

# Add WebLogic Deploy Tooling installer to the WebLogic Image Tool cache
echo "Adding WDT installer to cache..."
if ! "${IMAGETOOL_SCRIPT}" cache addInstaller --force --type=wdt --path="${WDT_INSTALLER}" --version=${WDT_VERSION}; then
    echo "Failed to add WebLogic Deploy Tooling installer ${WDT_INSTALLER} with version ${WDT_VERSION} to the WebLogic Image Tool cache">&2
    exit 1
fi

# Collect arguments for creating the image
# Platform is native (linux/amd64) so no need to specify
WIT_CREATE_AUX_IMAGE_ARGS="createAuxImage --builder=${IMAGE_BUILDER_EXE} --tag=${IMAGE_TAG}"

if [ "${HTTPS_PROXY}" != "" ]; then
    WIT_CREATE_AUX_IMAGE_ARGS="${WIT_CREATE_AUX_IMAGE_ARGS} --httpsProxyUrl=${HTTPS_PROXY}"
fi

if [ "${ALWAYS_PULL_BASE_IMAGE}" = "true" ]; then
    WIT_CREATE_AUX_IMAGE_ARGS="${WIT_CREATE_AUX_IMAGE_ARGS} --pull"
fi

# Gather WDT-related arguments
WIT_CREATE_AUX_IMAGE_ARGS="${WIT_CREATE_AUX_IMAGE_ARGS} --wdtVersion=${WDT_VERSION}"

if [ "${WDT_HOME}" != "" ]; then
    WIT_CREATE_AUX_IMAGE_ARGS="${WIT_CREATE_AUX_IMAGE_ARGS} --wdtHome=${WDT_HOME}"
fi

if [ "${WDT_MODEL_HOME}" != "" ]; then
    WIT_CREATE_AUX_IMAGE_ARGS="${WIT_CREATE_AUX_IMAGE_ARGS} --wdtModelHome=${WDT_MODEL_HOME}"
fi

if [ "${WDT_MODEL_FILE}" != "" ]; then
    WIT_CREATE_AUX_IMAGE_ARGS="${WIT_CREATE_AUX_IMAGE_ARGS} --wdtModel=${WDT_MODEL_FILE}"
fi

if [ "${WDT_VARIABLE_FILE}" != "" ]; then
    WIT_CREATE_AUX_IMAGE_ARGS="${WIT_CREATE_AUX_IMAGE_ARGS} --wdtVariables=${WDT_VARIABLE_FILE}"
fi

if [ "${WDT_ARCHIVE_FILE}" != "" ]; then
    WIT_CREATE_AUX_IMAGE_ARGS="${WIT_CREATE_AUX_IMAGE_ARGS} --wdtArchive=${WDT_ARCHIVE_FILE}"
fi

if [ "${TARGET}" != "" ]; then
    WIT_CREATE_AUX_IMAGE_ARGS="${WIT_CREATE_AUX_IMAGE_ARGS} --target=${TARGET}"
fi

if [ "${CHOWN}" != "" ]; then
    WIT_CREATE_AUX_IMAGE_ARGS="${WIT_CREATE_AUX_IMAGE_ARGS} --chown=${CHOWN}"
fi

if [ "${BUILD_NETWORK}" != "" ]; then
    WIT_CREATE_AUX_IMAGE_ARGS="${WIT_CREATE_AUX_IMAGE_ARGS} --buildNetwork=${BUILD_NETWORK}"
fi

if [ "${ADDITIONAL_BUILD_COMMANDS_FILE}" != "" ]; then
    WIT_CREATE_AUX_IMAGE_ARGS="${WIT_CREATE_AUX_IMAGE_ARGS} --additionalBuildCommands=${ADDITIONAL_BUILD_COMMANDS_FILE}"
fi

if [ "${ADDITIONAL_BUILD_FILES}" != "" ]; then
    WIT_CREATE_AUX_IMAGE_ARGS="${WIT_CREATE_AUX_IMAGE_ARGS} --additionalBuildFiles=${ADDITIONAL_BUILD_FILES}"
fi

# Create the image
echo "Creating auxiliary image..."
echo "Command: ${IMAGETOOL_SCRIPT} ${WIT_CREATE_AUX_IMAGE_ARGS}"
if ! "${IMAGETOOL_SCRIPT}" ${WIT_CREATE_AUX_IMAGE_ARGS}; then
    echo "Failed to create image ${IMAGE_TAG}">&2
    exit 1
fi

# Verify image architecture
echo ""
echo "Verifying image architecture..."
ARCH=$(podman inspect ${IMAGE_TAG} | grep -m1 '"Architecture"' | awk '{print $2}' | tr -d '",')
echo "Image architecture: ${ARCH}"

if [ "${ARCH}" != "amd64" ]; then
    echo "WARNING: Image architecture is ${ARCH}, expected amd64">&2
fi

# Login to the Image Registry
echo ""
echo "Logging in to ${IMAGE_REGISTRY_HOST}..."
if [ "${IMAGE_PUSH_REQUIRES_AUTH}" = "true" ]; then
    if [ "${IMAGE_REGISTRY_PUSH_USER}" != "" ] && [ "${IMAGE_REGISTRY_PUSH_PASS}" != "" ]; then
        if ! echo "${IMAGE_REGISTRY_PUSH_PASS}" | ${IMAGE_BUILDER_EXE} login --username ${IMAGE_REGISTRY_PUSH_USER} --password-stdin ${IMAGE_REGISTRY_HOST}; then
            echo "Failed to log in to the image registry ${IMAGE_REGISTRY_HOST}">&2
            exit 1
        fi
    fi
fi

# Push image
echo ""
echo "Pushing image ${IMAGE_TAG} to ${IMAGE_REGISTRY_HOST}..."
if ! "${IMAGE_BUILDER_EXE}" push ${IMAGE_TAG}; then
    echo "Failed to push image ${IMAGE_TAG} to the image registry ${IMAGE_REGISTRY_HOST}">&2
    exit 1
else
    echo ""
    echo "========================================="
    echo "SUCCESS!"
    echo "========================================="
    echo "Image ${IMAGE_TAG} successfully pushed to ${IMAGE_REGISTRY_HOST}"
    echo "Architecture: ${ARCH}"
    echo ""
fi
