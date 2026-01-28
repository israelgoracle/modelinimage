#!/usr/bin/env sh
# 
# This script installs a WebLogic domain into Kubernetes to be managed by
# the WebLogic Kubernetes Operator.  It depends on having the Kubernetes
# client configuration correctly configured to authenticate to the cluster
# with sufficient permissions to run the commands.
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
# HTTPS_PROXY="http://tw-proxy-lhr.oraclecorp.com:80"  # DESCOMENTADO

# Leave blank if no proxy bypass is required or comment out this
# line if inheriting NO_PROXY from the environment.
# NO_PROXY="localhost,127.0.0.1,.oraclecorp.com,.oracle.com"  # AMPLIADO

# The cluster context in your KUBECONFIG file to use.
# Set to empty if switching context is not needed.
KUBECTL_CONTEXT="telco"


DOMAIN_NAMESPACE="cohi-ns"

WKO_NAME="weblogic-operator"
WKO_CHART_NAME="weblogic-operator/weblogic-operator"
WKO_NAMESPACE="weblogic-operator-ns"
WKO_NS_STRATEGY="LabelSelector"
WKO_NS_LABEL_SELECTOR="weblogic-operator=enabled"

PULL_REQUIRES_AUTHENTICATION="true"
USE_EXISTING_PULL_SECRET="false"
PULL_SECRET_NAME="ocr"
PULL_SECRET_HOST="container-registry.oracle.com"
PULL_SECRET_EMAIL="israel.gutierrez@oracle.com"
PULL_SECRET_USER="israel.gutierrez@oracle.com"
PULL_SECRET_PASS="C15LldaT+2FbJsSQOLafL"

AUX_PULL_REQUIRES_AUTHENTICATION="true"
AUX_USE_EXISTING_PULL_SECRET="false"
AUX_PULL_SECRET_NAME="ocir"
AUX_PULL_SECRET_HOST="mad.ocir.io"
AUX_PULL_SECRET_EMAIL=""
AUX_PULL_SECRET_USER="axojlwfywuhi/israel.gutierrez@oracle.com"
AUX_PULL_SECRET_PASS="L>wTBGPs5QPnF(8wkbbq"

RUNTIME_SECRET_NAME="cohi-runtime-encryption-secret"
RUNTIME_SECRET_PASS="3b925e15-122c-4041-ac72-aa630a3d530f"

DOMAIN_SECRET_NAME="cohi-weblogic-credentials"
DOMAIN_SECRET_USER="weblogic"
DOMAIN_SECRET_PASS="welcome1"

COHI_JDBC_UOD_CATALG1_DS_XA_NAME="cohi-jdbc-uod-catalg1-ds-xa"
COHI_JDBC_UOD_CATALG1_DS_XA_PASSWORD="Welcome1Telco"
COHI_JDBC_UOD_CATALG1_DS_XA_USERNAME="CATALG1"

COHI_JDBC_UOD_CLIENT1_DS_XA_NAME="cohi-jdbc-uod-client1-ds-xa"
COHI_JDBC_UOD_CLIENT1_DS_XA_PASSWORD="Welcome1Telco"
COHI_JDBC_UOD_CLIENT1_DS_XA_USERNAME="CLIENT1"

COHI_JDBC_UOD_CNALES1_DS_XA_NAME="cohi-jdbc-uod-cnales1-ds-xa"
COHI_JDBC_UOD_CNALES1_DS_XA_PASSWORD="Welcome1Telco"
COHI_JDBC_UOD_CNALES1_DS_XA_USERNAME="CNALES1"

COHI_JDBC_UOD_COBROS1_DS_XA_NAME="cohi-jdbc-uod-cobros1-ds-xa"
COHI_JDBC_UOD_COBROS1_DS_XA_PASSWORD="Welcome1Telco"
COHI_JDBC_UOD_COBROS1_DS_XA_USERNAME="COBROS1"

COHI_JDBC_UOD_COCOTE1_DS_XA_NAME="cohi-jdbc-uod-cocote1-ds-xa"
COHI_JDBC_UOD_COCOTE1_DS_XA_PASSWORD="Welcome1Telco"
COHI_JDBC_UOD_COCOTE1_DS_XA_USERNAME="COCOTE1"

COHI_JDBC_UOD_GESTOR1_DS_XA_NAME="cohi-jdbc-uod-gestor1-ds-xa"
COHI_JDBC_UOD_GESTOR1_DS_XA_PASSWORD="Welcome1Telco"
COHI_JDBC_UOD_GESTOR1_DS_XA_USERNAME="GESTOR1"

COHI_JDBC_UOD_GIFTRA1_DS_XA_NAME="cohi-jdbc-uod-giftra1-ds-xa"
COHI_JDBC_UOD_GIFTRA1_DS_XA_PASSWORD="Welcome1Telco"
COHI_JDBC_UOD_GIFTRA1_DS_XA_USERNAME="GIFTRA1"

COHI_JDBC_UOD_GISSTE1_DS_NAME="cohi-jdbc-uod-gisste1-ds"
COHI_JDBC_UOD_GISSTE1_DS_PASSWORD="Welcome1Telco"
COHI_JDBC_UOD_GISSTE1_DS_USERNAME="GISSTE1"

COHI_JDBC_UOD_INUBIC1_DS_XA_NAME="cohi-jdbc-uod-inubic1-ds-xa"
COHI_JDBC_UOD_INUBIC1_DS_XA_PASSWORD="Welcome1Telco"
COHI_JDBC_UOD_INUBIC1_DS_XA_USERNAME="INUBIC1"

DOMAIN_CONFIG_MAP_YAML="/home/opc/wkt/WKT/COHI/cohi-configMap.yaml"
DOMAIN_RESOURCE_YAML="/home/opc/wkt/WKT/COHI/cohi-domain.yaml"

################################################################################
# End user-defined variable section (no edits needed below this line)          #
################################################################################

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

# Make sure that Operator is already installed.
if ! "${KUBECTL_EXE}" get deployment ${WKO_NAME} --namespace ${WKO_NAMESPACE}; then
    echo "WebLogic Kubernetes Operator ${WKO_NAME} is not installed in namespace ${WKO_NAMESPACE}">&2
    exit 1
else
    echo "WebLogic Kubernetes Operator ${WKO_NAME} is already installed in namespace ${WKO_NAMESPACE}"
fi

# Create the domain namespace if it does not already exist.
if ! "${KUBECTL_EXE}" get namespace ${DOMAIN_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create namespace ${DOMAIN_NAMESPACE}; then
        echo "Failed to create namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Namespace ${DOMAIN_NAMESPACE} already exists"
fi

# Prepare for operator upgrade to pick up domain namespace.
HELM_CHART_ARGS=""
if [ "${WKO_NS_STRATEGY}" = "LabelSelector" ]; then
    if ! "${KUBECTL_EXE}" label --overwrite namespace ${DOMAIN_NAMESPACE} ${WKO_NS_LABEL_SELECTOR}; then
        echo "Failed to add label "weblogic-operator=enabled" to namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
elif [ "${WKO_NS_STRATEGY}" = "List" ]; then
    HELM_CHART_ARGS="--set domainNamespaces=${WKO_DOMAIN_NAMESPACES}"
elif [ "${WKO_NS_STRATEGY}" = "Regexp" ]; then
    echo "WebLogic Kubernetes Operator is configured to use the Regexp namespace selection strategy so please make sure the namespace ${DOMAIN_NAMESPACE} matches the regular expression"
fi

# Run operator upgrade to pick up domain namespace.
if ! "${HELM_EXE}" upgrade ${WKO_NAME} ${WKO_CHART_NAME} --namespace ${WKO_NAMESPACE} --reuse-values ${HELM_CHART_ARGS} --wait; then
    echo "Failed to upgrade WebLogic Kubernetes Operator ${WKO_NAME} in namespace ${WKO_NAMESPACE}">&2
    exit 1
fi

# Create image pull secret, if needed.
if [ "${PULL_REQUIRES_AUTHENTICATION}" = "true" ] && [ "${USE_EXISTING_PULL_SECRET}" = "false" ]; then
    if ! "${KUBECTL_EXE}" get secret ${PULL_SECRET_NAME} --namespace ${DOMAIN_NAMESPACE}; then
        if ! "${KUBECTL_EXE}" create secret docker-registry ${PULL_SECRET_NAME} --namespace ${DOMAIN_NAMESPACE} --docker-server=${PULL_SECRET_HOST} --docker-username=${PULL_SECRET_USER} --docker-password=${PULL_SECRET_PASS} --docker-email=${PULL_SECRET_EMAIL}; then
            echo "Failed to create pull secret ${PULL_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}">&2
            exit 1
        fi
    else
        echo "Replacing existing pull secret ${PULL_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}"
        if ! "${KUBECTL_EXE}" delete secret ${PULL_SECRET_NAME} --namespace ${DOMAIN_NAMESPACE}; then
            echo "Failed to delete pull secret ${PULL_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}">&2
            exit 1
        fi
        if ! "${KUBECTL_EXE}" create secret docker-registry ${PULL_SECRET_NAME} --namespace ${DOMAIN_NAMESPACE} --docker-server=${PULL_SECRET_HOST} --docker-username=${PULL_SECRET_USER} --docker-password=${PULL_SECRET_PASS} --docker-email=${PULL_SECRET_EMAIL}; then
            echo "Failed to create pull secret ${PULL_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}">&2
            exit 1
        fi
    fi
fi

# Create auxiliary image pull secret, if needed.
if [ "${AUX_PULL_REQUIRES_AUTHENTICATION}" = "true" ] && [ "${AUX_USE_EXISTING_PULL_SECRET}" = "false" ]; then
    if ! "${KUBECTL_EXE}" get secret ${AUX_PULL_SECRET_NAME} --namespace ${DOMAIN_NAMESPACE}; then
        if ! "${KUBECTL_EXE}" create secret docker-registry ${AUX_PULL_SECRET_NAME} --namespace ${DOMAIN_NAMESPACE} --docker-server=${AUX_PULL_SECRET_HOST} --docker-username=${AUX_PULL_SECRET_USER} --docker-password=${AUX_PULL_SECRET_PASS} --docker-email=${AUX_PULL_SECRET_EMAIL}; then
            echo "Failed to create pull secret ${AUX_PULL_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}">&2
            exit 1
        fi
    else
        echo "Replacing existing pull secret ${AUX_PULL_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}"
        if ! "${KUBECTL_EXE}" delete secret ${AUX_PULL_SECRET_NAME} --namespace ${DOMAIN_NAMESPACE}; then
            echo "Failed to delete pull secret ${AUX_PULL_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}">&2
            exit 1
        fi
        if ! "${KUBECTL_EXE}" create secret docker-registry ${AUX_PULL_SECRET_NAME} --namespace ${DOMAIN_NAMESPACE} --docker-server=${AUX_PULL_SECRET_HOST} --docker-username=${AUX_PULL_SECRET_USER} --docker-password=${AUX_PULL_SECRET_PASS} --docker-email=${AUX_PULL_SECRET_EMAIL}; then
            echo "Failed to create pull secret ${AUX_PULL_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}">&2
            exit 1
        fi
    fi
fi

# Create runtime encryption secret.
if ! "${KUBECTL_EXE}" get secret ${RUNTIME_SECRET_NAME} --namespace ${DOMAIN_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create secret generic ${RUNTIME_SECRET_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${RUNTIME_SECRET_PASS}; then
        echo "Failed to create runtime encryption secret ${RUNTIME_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Replacing existing runtime encryption secret ${RUNTIME_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}"
    if ! "${KUBECTL_EXE}" delete secret ${RUNTIME_SECRET_NAME} --namespace ${DOMAIN_NAMESPACE}; then
        echo "Failed to delete runtime encryption secret ${RUNTIME_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
    if ! "${KUBECTL_EXE}" create secret generic ${RUNTIME_SECRET_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${RUNTIME_SECRET_PASS}; then
        echo "Failed to create runtime encryption secret ${RUNTIME_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
fi

# Create WebLogic domain credentials secret.
if ! "${KUBECTL_EXE}" get secret ${DOMAIN_SECRET_NAME} --namespace ${DOMAIN_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create secret generic ${DOMAIN_SECRET_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=username=${DOMAIN_SECRET_USER} --from-literal=password=${DOMAIN_SECRET_PASS}; then
        echo "Failed to create WebLogic domain credentials secret ${DOMAIN_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Replacing existing WebLogic domain credentials secret ${DOMAIN_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}"
    if ! "${KUBECTL_EXE}" delete secret ${DOMAIN_SECRET_NAME} --namespace ${DOMAIN_NAMESPACE}; then
        echo "Failed to delete WebLogic domain credentials secret ${DOMAIN_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
    if ! "${KUBECTL_EXE}" create secret generic ${DOMAIN_SECRET_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=username=${DOMAIN_SECRET_USER} --from-literal=password=${DOMAIN_SECRET_PASS}; then
        echo "Failed to create WebLogic domain credentials secret ${DOMAIN_SECRET_NAME} in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
fi

# Create the cohi-jdbc-uod-catalg1-ds-xa secret
if ! "${KUBECTL_EXE}" get secret ${COHI_JDBC_UOD_CATALG1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_CATALG1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_CATALG1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_CATALG1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-catalg1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Replacing existing secret cohi-jdbc-uod-catalg1-ds-xa in namespace ${DOMAIN_NAMESPACE}"
    if ! "${KUBECTL_EXE}" delete secret ${COHI_JDBC_UOD_CATALG1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
        echo "Failed to delete secret cohi-jdbc-uod-catalg1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_CATALG1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_CATALG1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_CATALG1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-catalg1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
fi

# Create the cohi-jdbc-uod-client1-ds-xa secret
if ! "${KUBECTL_EXE}" get secret ${COHI_JDBC_UOD_CLIENT1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_CLIENT1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_CLIENT1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_CLIENT1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-client1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Replacing existing secret cohi-jdbc-uod-client1-ds-xa in namespace ${DOMAIN_NAMESPACE}"
    if ! "${KUBECTL_EXE}" delete secret ${COHI_JDBC_UOD_CLIENT1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
        echo "Failed to delete secret cohi-jdbc-uod-client1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_CLIENT1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_CLIENT1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_CLIENT1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-client1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
fi

# Create the cohi-jdbc-uod-cnales1-ds-xa secret
if ! "${KUBECTL_EXE}" get secret ${COHI_JDBC_UOD_CNALES1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_CNALES1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_CNALES1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_CNALES1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-cnales1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Replacing existing secret cohi-jdbc-uod-cnales1-ds-xa in namespace ${DOMAIN_NAMESPACE}"
    if ! "${KUBECTL_EXE}" delete secret ${COHI_JDBC_UOD_CNALES1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
        echo "Failed to delete secret cohi-jdbc-uod-cnales1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_CNALES1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_CNALES1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_CNALES1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-cnales1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
fi

# Create the cohi-jdbc-uod-cobros1-ds-xa secret
if ! "${KUBECTL_EXE}" get secret ${COHI_JDBC_UOD_COBROS1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_COBROS1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_COBROS1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_COBROS1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-cobros1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Replacing existing secret cohi-jdbc-uod-cobros1-ds-xa in namespace ${DOMAIN_NAMESPACE}"
    if ! "${KUBECTL_EXE}" delete secret ${COHI_JDBC_UOD_COBROS1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
        echo "Failed to delete secret cohi-jdbc-uod-cobros1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_COBROS1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_COBROS1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_COBROS1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-cobros1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
fi

# Create the cohi-jdbc-uod-cocote1-ds-xa secret
if ! "${KUBECTL_EXE}" get secret ${COHI_JDBC_UOD_COCOTE1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_COCOTE1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_COCOTE1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_COCOTE1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-cocote1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Replacing existing secret cohi-jdbc-uod-cocote1-ds-xa in namespace ${DOMAIN_NAMESPACE}"
    if ! "${KUBECTL_EXE}" delete secret ${COHI_JDBC_UOD_COCOTE1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
        echo "Failed to delete secret cohi-jdbc-uod-cocote1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_COCOTE1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_COCOTE1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_COCOTE1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-cocote1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
fi

# Create the cohi-jdbc-uod-gestor1-ds-xa secret
if ! "${KUBECTL_EXE}" get secret ${COHI_JDBC_UOD_GESTOR1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_GESTOR1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_GESTOR1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_GESTOR1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-gestor1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Replacing existing secret cohi-jdbc-uod-gestor1-ds-xa in namespace ${DOMAIN_NAMESPACE}"
    if ! "${KUBECTL_EXE}" delete secret ${COHI_JDBC_UOD_GESTOR1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
        echo "Failed to delete secret cohi-jdbc-uod-gestor1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_GESTOR1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_GESTOR1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_GESTOR1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-gestor1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
fi

# Create the cohi-jdbc-uod-giftra1-ds-xa secret
if ! "${KUBECTL_EXE}" get secret ${COHI_JDBC_UOD_GIFTRA1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_GIFTRA1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_GIFTRA1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_GIFTRA1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-giftra1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Replacing existing secret cohi-jdbc-uod-giftra1-ds-xa in namespace ${DOMAIN_NAMESPACE}"
    if ! "${KUBECTL_EXE}" delete secret ${COHI_JDBC_UOD_GIFTRA1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
        echo "Failed to delete secret cohi-jdbc-uod-giftra1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_GIFTRA1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_GIFTRA1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_GIFTRA1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-giftra1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
fi

# Create the cohi-jdbc-uod-gisste1-ds secret
if ! "${KUBECTL_EXE}" get secret ${COHI_JDBC_UOD_GISSTE1_DS_NAME} --namespace ${DOMAIN_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_GISSTE1_DS_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_GISSTE1_DS_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_GISSTE1_DS_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-gisste1-ds in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Replacing existing secret cohi-jdbc-uod-gisste1-ds in namespace ${DOMAIN_NAMESPACE}"
    if ! "${KUBECTL_EXE}" delete secret ${COHI_JDBC_UOD_GISSTE1_DS_NAME} --namespace ${DOMAIN_NAMESPACE}; then
        echo "Failed to delete secret cohi-jdbc-uod-gisste1-ds in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_GISSTE1_DS_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_GISSTE1_DS_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_GISSTE1_DS_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-gisste1-ds in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
fi

# Create the cohi-jdbc-uod-inubic1-ds-xa secret
if ! "${KUBECTL_EXE}" get secret ${COHI_JDBC_UOD_INUBIC1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_INUBIC1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_INUBIC1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_INUBIC1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-inubic1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Replacing existing secret cohi-jdbc-uod-inubic1-ds-xa in namespace ${DOMAIN_NAMESPACE}"
    if ! "${KUBECTL_EXE}" delete secret ${COHI_JDBC_UOD_INUBIC1_DS_XA_NAME} --namespace ${DOMAIN_NAMESPACE}; then
        echo "Failed to delete secret cohi-jdbc-uod-inubic1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
    if ! "${KUBECTL_EXE}" create secret generic ${COHI_JDBC_UOD_INUBIC1_DS_XA_NAME} --namespace=${DOMAIN_NAMESPACE} --from-literal=password=${COHI_JDBC_UOD_INUBIC1_DS_XA_PASSWORD} --from-literal=username=${COHI_JDBC_UOD_INUBIC1_DS_XA_USERNAME}; then
        echo "Failed to create secret cohi-jdbc-uod-inubic1-ds-xa in namespace ${DOMAIN_NAMESPACE}">&2
        exit 1
    fi
fi

# Create domain ConfigMap cohi-config-map
if ! "${KUBECTL_EXE}" apply -f "${DOMAIN_CONFIG_MAP_YAML}"; then
    echo "Failed to create domain ConfigMap cohi-config-map">&2
    exit 1
fi

# Create domain resource
if ! "${KUBECTL_EXE}" apply -f "${DOMAIN_RESOURCE_YAML}"; then
    echo "Failed to create domain resource">&2
    exit 1
fi


