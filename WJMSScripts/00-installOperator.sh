#!/usr/bin/env sh
# 
# This script installs the WebLogic Kubernetes Operator into a Kubernetes cluster.
# It depends on having the Kubernetes client configuration correctly configured to
# authenticate to the cluster with sufficient permissions to run the installation.
# 
# Copyright (c) 2021, 2025, Oracle and/or its affiliates.
# Licensed under The Universal Permissive License (UPL), Version 1.0
# as shown at https://oss.oracle.com/licenses/upl/.
# 

################################################################################
# Start user-defined variable section (edit as needed)                         #
################################################################################

KUBECTL_EXE="/usr/local/bin/kubectl"
HELM_EXE="/usr/local/bin/helm"

# Leave blank if using the default Kubernetes client config file or
# comment out this line if inheriting KUBECONFIG from the environment.
KUBECONFIG="/home/opc/.kube/config"

# Leave blank if no proxy is required or comment out this line if
# inheriting HTTPS_PROXY from the environment.
# HTTPS_PROXY="http://tw-proxy-lhr.oraclecorp.com:80"

# Leave blank if no proxy bypass is required or comment out this
# line if inheriting NO_PROXY from the environment.
NO_PROXY=""

# The cluster context in your KUBECONFIG file to use.
# Set to empty if switching context is not needed.
KUBECTL_CONTEXT="telco"

WKO_NAME="weblogic-operator"
WKO_NAMESPACE="weblogic-operator-ns"
WKO_SERVICE_ACCOUNT="weblogic-operator-sa"

WKO_IMAGE_TAG=""
WKO_PULL_REQUIRES_AUTHENTICATION="false"
# This field must not be empty if WKO_PULL_REQUIRES_AUTHENTICATION is set to true.
WKO_PULL_SECRET_NAME=""
# Setting this to "false" will result in the secret being overwritten if it already exists.
WKO_USE_EXISTING_PULL_SECRET="true"

# This field must be set to match the registry address in the WKO_IMAGE_TAG value.
WKO_PULL_HOST=""
WKO_PULL_USER=""
WKO_PULL_PASS=""
WKO_PULL_EMAIL=""

# Operator helm chart values
# 
# Allowed values are LabelSelector, List, Regexp, Dedicated
WKO_DOMAIN_NAMESPACE_SELECTION_STRATEGY="LabelSelector"

# Only used if WKO_DOMAIN_NAMESPACE_SELECTION_STRATEGY is set to LabelSelector.
WKO_DOMAIN_NAMESPACE_LABEL_SELECTOR="weblogic-operator=enabled"

# Only used if WKO_DOMAIN_NAMESPACE_SELECTION_STRATEGY is set to List.
# If set, the value must be of the form "{<name>[,<name>]*}"
WKO_DOMAIN_NAMESPACES=""

# Only used if WKO_DOMAIN_NAMESPACE_SELECTION_STRATEGY is set to Regexp.
WKO_DOMAIN_NAMESPACE_REGEX=""

WKO_ENABLE_CLUSTER_ROLE_BINDING=""
WKO_IMAGE_PULL_POLICY=""

WKO_EXTERNAL_REST_ENABLED=""
# Only used if WKO_EXTERNAL_REST_ENABLED is set to true
WKO_EXTERNAL_REST_HTTPS_PORT=""
WKO_EXTERNAL_REST_IDENTITY_SECRET=""

WKO_ELK_INTEGRATION_ENABLED=""
# These three fields are only used if WKO_ELK_INTEGRATION_ENABLED is set to true.
WKO_LOGSTASH_IMAGE=""
WKO_ELASTICSEARCH_HOST=""
WKO_ELASTICSEARCH_PORT=""

# Legal values are "SEVERE", "WARNING", "INFO", "CONFIG", "FINE", "FINER", and "FINEST".
# An empty value will use the default value of INFO.
WKO_JAVA_LOGGING_LEVEL=""
# The maximum size in bytes for a single log file.
WKO_JAVA_LOGGING_FILE_SIZE_LIMIT=""
# The maximum number of retained log files.
WKO_JAVA_LOGGING_FILE_COUNT=""

# The number of minutes for the helm command to wait for completion (e.g., 10)
HELM_TIMEOUT=""

################################################################################
# End user-defined variable section (no edits needed below this line)          #
################################################################################

WKO_CHART_REPO_NAME="weblogic-operator"
WKO_CHART_NAME="weblogic-operator/weblogic-operator"
WKO_CHART_URL="https://oracle.github.io/weblogic-kubernetes-operator/charts/"

if [ "$KUBECONFIG" != "" ]; then
    export KUBECONFIG
fi

if [ "$HTTPS_PROXY" != "" ]; then
    export HTTPS_PROXY
fi

if [ "$NO_PROXY" != "" ]; then
    export NO_PROXY
fi

# Switch to configured kubectl context, if required.
if [ "${KUBECTL_CONTEXT}" != "" ]; then
    if ! "${KUBECTL_EXE}" config use-context ${KUBECTL_CONTEXT}; then
        echo "Failed to switch kubectl to use the context ${KUBECTL_CONTEXT}">&2
        exit 1
    fi
fi

if ! "${KUBECTL_EXE}" get deployment ${WKO_NAME} --namespace ${WKO_NAMESPACE}; then
    echo "WebLogic Kubernetes Operator ${WKO_NAME} is not installed in namespace ${WKO_NAMESPACE}"
else
    echo "WebLogic Kubernetes Operator ${WKO_NAME} is already installed in namespace ${WKO_NAMESPACE}">&2
    exit 1
fi

if ! "${KUBECTL_EXE}" get namespace ${WKO_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create namespace ${WKO_NAMESPACE}; then
        echo "Failed to create namespace ${WKO_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Namespace ${WKO_NAMESPACE} already exists"
fi

if ! "${KUBECTL_EXE}" get serviceaccount ${WKO_SERVICE_ACCOUNT} --namespace ${WKO_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create serviceaccount ${WKO_SERVICE_ACCOUNT} --namespace ${WKO_NAMESPACE}; then
        echo "Failed to create service account ${WKO_SERVICE_ACCOUNT}">&2
        exit 1
    fi
else
    echo "Service account ${WKO_SERVICE_ACCOUNT} already exists"
fi

if [ "${WKO_PULL_REQUIRES_AUTHENTICATION}" = "true" ] && [ "${WKO_USE_EXISTING_PULL_SECRET}" = "false" ]; then
    if ! "${KUBECTL_EXE}" get secret ${WKO_PULL_SECRET_NAME} --namespace ${WKO_NAMESPACE}; then
        if ! "${KUBECTL_EXE}" create secret docker-registry ${WKO_PULL_SECRET_NAME} --namespace ${WKO_NAMESPACE} --docker-server=${WKO_PULL_HOST} --docker-username=${WKO_PULL_USER} --docker-password=${WKO_PULL_PASS} --docker-email=${WKO_PULL_EMAIL}; then
            echo "Failed to create pull secret ${WKO_PULL_SECRET_NAME} in namespace ${WKO_NAMESPACE}">&2
            exit 1
        fi
    else
        echo "Replacing existing pull secret ${WKO_PULL_SECRET_NAME} in namespace ${WKO_NAMESPACE}"
        if ! "${KUBECTL_EXE}" delete secret ${WKO_PULL_SECRET_NAME} --namespace ${WKO_NAMESPACE}; then
            echo "Failed to delete pull secret ${WKO_PULL_SECRET_NAME} in namespace ${WKO_NAMESPACE}">&2
            exit 1
        fi
        if ! "${KUBECTL_EXE}" create secret docker-registry ${WKO_PULL_SECRET_NAME} --namespace ${WKO_NAMESPACE} --docker-server=${WKO_PULL_HOST} --docker-username=${WKO_PULL_USER} --docker-password=${WKO_PULL_PASS} --docker-email=${WKO_PULL_EMAIL}; then
            echo "Failed to create pull secret ${WKO_PULL_SECRET_NAME} in namespace ${WKO_NAMESPACE}">&2
            exit 1
        fi
    fi
fi

if ! "${HELM_EXE}" repo add ${WKO_CHART_REPO_NAME} ${WKO_CHART_URL} --force-update; then
    echo "Failed to add WebLogic Kubernetes Operator helm chart to the local repo">&2
    exit 1
fi

# Prepare the Helm Chart values arguments.
HELM_CHART_ARGS="--set domainNamespaceSelectionStrategy=${WKO_DOMAIN_NAMESPACE_SELECTION_STRATEGY}"
if [ "${WKO_DOMAIN_NAMESPACE_SELECTION_STRATEGY}" = "LabelSelector" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --set domainNamespaceLabelSelector=${WKO_DOMAIN_NAMESPACE_LABEL_SELECTOR}"
elif [ "${WKO_DOMAIN_NAMESPACE_SELECTION_STRATEGY}" = "List" ] && [ "${WKO_DOMAIN_NAMESPACES}" != "" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --set domainNamespaces=${WKO_DOMAIN_NAMESPACES}"
elif [ "${WKO_DOMAIN_NAMESPACE_SELECTION_STRATEGY}" = "RegExp" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --set domainNamespaceRegExp=${WKO_DOMAIN_NAMESPACE_REGEX}"
fi

if [ "${WKO_IMAGE_TAG}" != "" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --set image=${WKO_IMAGE_TAG}"
fi

if [ "${WKO_SERVICE_ACCOUNT}" != "" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --set serviceAccount=${WKO_SERVICE_ACCOUNT}"
fi

if [ "${WKO_PULL_REQUIRES_AUTHENTICATION}" = "true" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --set imagePullSecrets=${WKO_PULL_SECRET_NAME}"
fi

if [ "${WKO_ENABLE_CLUSTER_ROLE_BINDING}" = "true" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --set enableClusterRoleBinding=${WKO_ENABLE_CLUSTER_ROLE_BINDING}"
fi

if [ "${WKO_IMAGE_PULL_POLICY}" != "" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --set imagePullPolicy=${WKO_IMAGE_PULL_POLICY}"
fi

if [ "${WKO_EXTERNAL_REST_ENABLED}" = "true" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --set externalRestEnabled=${WKO_EXTERNAL_REST_ENABLED}"
    if [ "${WKO_EXTERNAL_REST_HTTPS_PORT}" != "" ]; then
        HELM_CHART_ARGS="${HELM_CHART_ARGS} --set externalRestHttpsPort=${WKO_EXTERNAL_REST_HTTPS_PORT}"
    fi
    if [ "${WKO_EXTERNAL_REST_IDENTITY_SECRET}" != "" ]; then
        HELM_CHART_ARGS="${HELM_CHART_ARGS} --set externalRestIdentitySecret=${WKO_EXTERNAL_REST_IDENTITY_SECRET}"
    fi
fi

if [ "${WKO_ELK_INTEGRATION_ENABLED}" = "true" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --set elkIntegrationEnabled=${WKO_ELK_INTEGRATION_ENABLED}"
    if [ "${WKO_LOGSTASH_IMAGE}" != "" ]; then
        HELM_CHART_ARGS="${HELM_CHART_ARGS} --set logStashImage=${WKO_LOGSTASH_IMAGE}"
    fi
    if [ "${WKO_ELASTICSEARCH_HOST}" != "" ]; then
        HELM_CHART_ARGS="${HELM_CHART_ARGS} --set elasticSearchHost=${WKO_ELASTICSEARCH_HOST}"
    fi
    if [ "${WKO_ELASTICSEARCH_PORT}" != "" ]; then
        HELM_CHART_ARGS="${HELM_CHART_ARGS} --set elasticSearchPort=${WKO_ELASTICSEARCH_PORT}"
    fi
fi

if [ "${WKO_JAVA_LOGGING_LEVEL}" != "" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --set javaLoggingLevel=${WKO_JAVA_LOGGING_LEVEL}"
fi
if [ "${WKO_JAVA_LOGGING_FILE_SIZE_LIMIT}" != "" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --set javaLoggingFileSizeLimit=${WKO_JAVA_LOGGING_FILE_SIZE_LIMIT}"
fi
if [ "${WKO_JAVA_LOGGING_FILE_COUNT}" != "" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --set javaLoggingFileCount=${WKO_JAVA_LOGGING_FILE_COUNT}"
fi

if [ "${HELM_TIMEOUT}" != "" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --timeout ${HELM_TIMEOUT}m"
fi

if ! "${HELM_EXE}" install ${WKO_NAME} ${WKO_CHART_NAME} --namespace ${WKO_NAMESPACE} ${HELM_CHART_ARGS} --wait; then
    echo "Failed to install WebLogic Kubernetes Operator ${WKO_NAME} to namespace ${WKO_NAMESPACE}">&2
    exit 1
else
    echo "Successfully installed WebLogic Kubernetes Operator ${WKO_NAME} to namespace ${WKO_NAMESPACE}"
fi

