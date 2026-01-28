#!/usr/bin/env sh
# 
# This script adds/updates ingress routes for your application
# using the specified ingress controller.
# 
# Copyright (c) 2021, 2025, Oracle and/or its affiliates.
# Licensed under The Universal Permissive License (UPL), Version 1.0
# as shown at https://oss.oracle.com/licenses/upl/.
# 

################################################################################
# Start user-defined variable section (edit as needed)                         #
################################################################################

KUBECTL_EXE="/usr/local/bin/kubectl"
OPENSSL_EXE="/usr/bin/openssl"

# Leave blank if using the default Kubernetes client config file or
# comment out this line if inheriting KUBECONFIG from the environment.
KUBECONFIG="/home/opc/.kube/config"



# The cluster context in your KUBECONFIG file to use.
# Set to empty if switching context is not needed.
KUBECTL_CONTEXT="telco"

# When using TLS with Ingress routes, you must specify the secret to use
# and create it if it does not already exist. If you do not have a certificate,
# this script can generate one for you using OpenSSL.
USE_TLS_SECRET="false"
USE_EXISTING_TLS_SECRET="true"
TLS_SECRET_NAME=""
TLS_SECRET_NAMESPACE="wcv2-ns"
GENERATE_TLS_SECRET="false"
TLS_CERT_FILE=""
TLS_PRIVATE_KEY_FILE=""

# Save the ingress routes yaml in a file and set the path here.
# Set to empty if there are no routes to add/update.
INGRESS_ROUTES_YAML="./050-ingresRoutes.yaml"

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

# Generate the TLS certificate and private key files, if needed.
if [ "${GENERATE_TLS_SECRET}" = "true" ]; then
    if ! "${OPENSSL_EXE}" req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "${GEN_TLS_KEY_OUT}" -out "${GEN_TLS_CERT_OUT}" -subj "${GEN_TLS_SUBJECT}"; then
        echo "Failed to generate TLS certificate and private key files">&2
        exit 1
    else
        echo "TLS certificate file ${GEN_TLS_CERT_OUT} and private key file ${GEN_TLS_KEY_OUT} generated"
    fi
fi

# Create the TLS secret namespace, if needed.
if [ "${TLS_USE_EXISTING_SECRET}" = "false" ]; then
    if ! "${KUBECTL_EXE}" create ${TLS_SECRET_NAMESPACE}; then
        echo "Failed to create namespace ${TLS_SECRET_NAMESPACE}">&2
        exit 1
    else
        echo "Namespace ${TLS_SECRET_NAMESPACE} already exists"
    fi
fi

# Create TLS secret, if needed.
if [ "${USE_TLS_SECRET}" = "true" ] && [ "${TLS_USE_EXISTING_SECRET}" = "false" ]; then
    if ! "${KUBECTL_EXE}" get secret ${TLS_SECRET_NAME} --namespace ${TLS_SECRET_NAMESPACE}; then
        if ! "${KUBECTL_EXE}" create secret tls ${TLS_SECRET_NAME} --namespace ${TLS_SECRET_NAMESPACE} --key ${TLS_SECRET_KEY} --cert ${TLS_SECRET_CERT}; then
            echo "Failed to create tls secret ${TLS_SECRET_NAME} in namespace ${TLS_SECRET_NAMESPACE}">&2
            exit 1
        fi
    else
        echo "Replacing existing tls secret ${TLS_SECRET_NAME} in namespace ${TLS_SECRET_NAMESPACE}"
        if ! "${KUBECTL_EXE}" delete secret ${TLS_SECRET_NAME} --namespace ${TLS_SECRET_NAMESPACE}; then
            echo "Failed to delete tls secret ${TLS_SECRET_NAME} in namespace ${TLS_SECRET_NAMESPACE}">&2
            exit 1
        fi
        if ! "${KUBECTL_EXE}" create secret tls ${TLS_SECRET_NAME} --namespace ${TLS_SECRET_NAMESPACE} --key ${TLS_SECRET_KEY} --cert ${TLS_SECRET_CERT}; then
            echo "Failed to create tls secret ${TLS_SECRET_NAME} in namespace ${TLS_SECRET_NAMESPACE}">&2
            exit 1
        fi
    fi
fi

# Add/update Ingress Routes.
if ! "${KUBECTL_EXE}" apply -f "${INGRESS_ROUTES_YAML}"; then
    echo "Failed to add/update routes using YAML file ${INGRESS_ROUTES_YAML}">&2
    exit 1
fi


