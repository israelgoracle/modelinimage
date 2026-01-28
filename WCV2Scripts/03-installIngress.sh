#!/usr/bin/env sh
# 
# This script installs an Kubernetes ingress controller and/or
# adds ingress routes to your application.
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


# The cluster context in your KUBECONFIG file to use.
# Set to empty if switching context is not needed.
KUBECTL_CONTEXT="telco"

INGRESS_CONTROLLER_TYPE="traefik"
INGRESS_REPO_NAME="ingress-traefik"
INGRESS_CHART_URL="https://helm.traefik.io/traefik"
INGRESS_CHART_NAME="ingress-traefik/traefik"
INGRESS_RELEASE_NAME="traefik-operator"
INGRESS_CONTROLLER_NAMESPACE="traefik-ns"

# Voyager and Traefik ingress images are located in Docker Hub.
# Docker Hub is throttling anonymous pull requests.  To workaround
# that issue, Set this value to true and provide the appropriate
# values in this set of environment variables.
USE_DOCKER_HUB_SECRET="true"
USE_EXISTING_DOCKER_HUB_SECRET="false"
DOCKER_HUB_SECRET_NAME="dockerhub"
DOCKER_HUB_USER="israelgoracle"
DOCKER_HUB_PASS="1qazxsw23edC!"
DOCKER_HUB_EMAIL="israel.gutierrez@oracle.com"

# If not using an external load balancer, the ingress controller service type to use (e.g., NodePort)
SERVICE_TYPE=""

# The number of minutes for the helm command to wait for completion (e.g., 10)
HELM_TIMEOUT=""

# ============================================================================
# OCI Load Balancer Configuration
# ============================================================================
# By default, this script creates a PRIVATE Load Balancer in OCI.
# The Load Balancer is created automatically by the OCI Cloud Controller Manager
# when Traefik is deployed with service.type=LoadBalancer.
#
# PRIVATE LB: Use this for clusters in private subnets (default, more secure)
# - Set OCI_LB_INTERNAL="true"
# - The LB will get a private IP from your load balancer subnet
# - Only accessible from within your VCN or via VPN/FastConnect/Bastion
#
# PUBLIC LB: Use this if you need external internet access to your ingress
# - Set OCI_LB_INTERNAL="false"
# - Requires a PUBLIC subnet for the load balancer
# - The LB will get a public IP address
# - Note: Your OKE cluster can still be private, only the LB subnet needs to be public
#
OCI_LB_INTERNAL="true"

# ============================================================================
# OCI Load Balancer Subnet Configuration
# ============================================================================
# Specify the OCIDs of the subnets where the Load Balancer should be created.
# OCI Load Balancers are regional and require subnet IDs for placement.
#
# IMPORTANT: 
# - For PRIVATE LB: Use your PRIVATE lb-subnet OCID(s)
# - For PUBLIC LB: Use your PUBLIC subnet OCID(s)
# - You can specify 1 or 2 subnet OCIDs (for multi-AD redundancy)
# - If using 2 subnets, separate them with a comma (no spaces)
#
# Example single subnet:
#   OCI_LB_SUBNET_IDS="ocid1.subnet.oc1.eu-milan-1.aaaaaaaxxxxx"
#
# Example two subnets (recommended for HA):
#   OCI_LB_SUBNET_IDS="ocid1.subnet.oc1.eu-milan-1.aaaaaaaxxxxx,ocid1.subnet.oc1.eu-milan-1.aaaaaaayyyyy"
#
# To find your subnet OCID:
#   oci network subnet list --compartment-id <compartment-id> --display-name "lb-subnet"
# Or from OCI Console: Networking -> VCN -> Subnets -> lb-subnet (copy OCID)
#
OCI_LB_SUBNET_IDS="ocid1.subnet.oc1.eu-madrid-1.aaaaaaaaokfzgocl3pvcu66japyfdrfyhtxaizhg7cx5zzxkldyuqnwnlpka"

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

# Create the namespace for the installation, if needed.
if ! "${KUBECTL_EXE}" get namespace ${INGRESS_CONTROLLER_NAMESPACE}; then
    if ! "${KUBECTL_EXE}" create namespace ${INGRESS_CONTROLLER_NAMESPACE}; then
        echo "Failed to create namespace ${INGRESS_CONTROLLER_NAMESPACE}">&2
        exit 1
    fi
else
    echo "Namespace ${INGRESS_CONTROLLER_NAMESPACE} already exists"
fi

# Create Docker Hub credentials secret, if needed.
if [ "${USE_DOCKER_HUB_SECRET}" = "true" ] && [ "${USE_EXISTING_DOCKER_HUB_SECRET}" = "false" ]; then
    if ! "${KUBECTL_EXE}" get secret ${DOCKER_HUB_SECRET_NAME} --namespace ${INGRESS_CONTROLLER_NAMESPACE}; then
        if ! "${KUBECTL_EXE}" create secret docker-registry ${DOCKER_HUB_SECRET_NAME} --namespace ${INGRESS_CONTROLLER_NAMESPACE} --docker-server=docker.io --docker-username=${DOCKER_HUB_USER} --docker-password=${DOCKER_HUB_PASS} --docker-email=${DOCKER_HUB_EMAIL}; then
            echo "Failed to create pull secret ${DOCKER_HUB_SECRET_NAME} in namespace ${INGRESS_CONTROLLER_NAMESPACE}">&2
            exit 1
        fi
    else
        echo "Replacing existing pull secret ${DOCKER_HUB_SECRET_NAME} in namespace ${INGRESS_CONTROLLER_NAMESPACE}"
        if ! "${KUBECTL_EXE}" delete secret ${DOCKER_HUB_SECRET_NAME} --namespace ${INGRESS_CONTROLLER_NAMESPACE}; then
            echo "Failed to delete pull secret ${DOCKER_HUB_SECRET_NAME} in namespace ${INGRESS_CONTROLLER_NAMESPACE}">&2
            exit 1
        fi
        if ! "${KUBECTL_EXE}" create secret docker-registry ${DOCKER_HUB_SECRET_NAME} --namespace ${INGRESS_CONTROLLER_NAMESPACE} --docker-server=docker.io --docker-username=${DOCKER_HUB_USER} --docker-password=${DOCKER_HUB_PASS} --docker-email=${DOCKER_HUB_EMAIL}; then
            echo "Failed to create pull secret ${DOCKER_HUB_SECRET_NAME} in namespace ${INGRESS_CONTROLLER_NAMESPACE}">&2
            exit 1
        fi
    fi
fi

# If using Voyager, add Helm chart value overrides
HELM_CHART_ARGS=""
if [ "${INGRESS_CONTROLLER_TYPE}" = "Voyager" ]; then
    if [ "${VOYAGER_PROVIDER}" != "" ]; then 
        HELM_CHART_ARGS="${HELM_CHART_ARGS} --set cloudProvider=${VOYAGER_PROVIDER}"
    fi
    if [ "${API_SERVER_ENABLE_HEALTH_CHECK}" != "" ]; then 
        HELM_CHART_ARGS="${HELM_CHART_ARGS} --set apiserver.healthcheck.enabled=${API_SERVER_ENABLE_HEALTH_CHECK}"
    fi
    if [ "${API_SERVER_ENABLE_VALIDATING_WEBHOOK}" != "" ]; then 
        HELM_CHART_ARGS="${HELM_CHART_ARGS} --set apiserver.enableValidationWebhook=${API_SERVER_ENABLE_VALIDATING_WEBHOOK}"
    fi
fi

# If not using an external load balancer, set the service type for the ingress controller
if [ "${SERVICE_TYPE}" != "LoadBalancer" ]; then
    if [ "${INGRESS_CONTROLLER_TYPE}" = "traefik" ]; then
        HELM_CHART_ARGS="${HELM_CHART_ARGS} --set service.type=${SERVICE_TYPE}"
    elif [ "${INGRESS_CONTROLLER_TYPE}" = "nginx" ]; then
        HELM_CHART_ARGS="${HELM_CHART_ARGS} --set controller.service.type=${SERVICE_TYPE}"
    fi
fi

# ============================================================================
# Configure OCI Load Balancer type (Private vs Public) and Subnet Placement
# ============================================================================
# These annotations tell the OCI Cloud Controller Manager:
# 1. What type of LB to create (private/public)
# 2. Which subnet(s) to place the LB in
#
# The LB is created automatically by Kubernetes - you don't create it manually in OCI.
#
# We use a temporary values file to ensure annotations are properly formatted as strings
#
TRAEFIK_VALUES_FILE="/tmp/traefik-values-$$.yaml"

cat > ${TRAEFIK_VALUES_FILE} << EOF
service:
  annotations:
EOF

if [ "${INGRESS_CONTROLLER_TYPE}" = "traefik" ]; then
    if [ "${OCI_LB_INTERNAL}" = "true" ]; then
        echo "Configuring Traefik to use a PRIVATE Load Balancer in OCI"
        cat >> ${TRAEFIK_VALUES_FILE} << EOF
    service.beta.kubernetes.io/oci-load-balancer-internal: "true"
EOF
    else
        echo "Configuring Traefik to use a PUBLIC Load Balancer in OCI"
        cat >> ${TRAEFIK_VALUES_FILE} << EOF
    service.beta.kubernetes.io/oci-load-balancer-internal: "false"
EOF
    fi
    
    # Specify the subnet(s) where the Load Balancer should be created
    if [ "${OCI_LB_SUBNET_IDS}" != "" ]; then
        echo "Configuring Load Balancer to use subnet(s): ${OCI_LB_SUBNET_IDS}"
        cat >> ${TRAEFIK_VALUES_FILE} << EOF
    service.beta.kubernetes.io/oci-load-balancer-subnet1: "${OCI_LB_SUBNET_IDS}"
EOF
    else
        echo "WARNING: OCI_LB_SUBNET_IDS not set. OCI will use default subnets from the cluster."
    fi
fi

# Add Docker Hub pull secret configuration if needed
if [ "${USE_DOCKER_HUB_SECRET}" = "true" ]; then
    if [ "${INGRESS_CONTROLLER_TYPE}" = "traefik" ]; then
        cat >> ${TRAEFIK_VALUES_FILE} << EOF
deployment:
  imagePullSecrets:
    - name: ${DOCKER_HUB_SECRET_NAME}
EOF
    fi
fi

# Add the values file to helm args
HELM_CHART_ARGS="${HELM_CHART_ARGS} -f ${TRAEFIK_VALUES_FILE}"

# The number of minutes for the helm command to wait for completion (e.g., 10)
if [ "${HELM_TIMEOUT}" != "" ]; then
    HELM_CHART_ARGS="${HELM_CHART_ARGS} --timeout ${HELM_TIMEOUT}m"
fi

# Add or update the ingress controller helm chart in the local repository.
if ! "${HELM_EXE}" repo add ${INGRESS_REPO_NAME} ${INGRESS_CHART_URL} --force-update; then
    echo "Failed to add ingress controller to the local repo ${INGRESS_REPO_NAME}">&2
    rm -f ${TRAEFIK_VALUES_FILE}
    exit 1
fi

echo "Generated Traefik values file:"
cat ${TRAEFIK_VALUES_FILE}
echo ""

# Install ingress controller.
if ! "${HELM_EXE}" install ${INGRESS_RELEASE_NAME} ${INGRESS_CHART_NAME} --namespace ${INGRESS_CONTROLLER_NAMESPACE} ${HELM_CHART_ARGS} --wait; then
    echo "Failed to install ${INGRESS_CONTROLLER_TYPE} ingress controller to namespace ${INGRESS_CONTROLLER_NAMESPACE}">&2
    rm -f ${TRAEFIK_VALUES_FILE}
    exit 1
else
    echo "Installed ${INGRESS_CONTROLLER_TYPE} ingress controller to namespace ${INGRESS_CONTROLLER_NAMESPACE}"
    echo ""
    echo "The OCI Load Balancer will be created automatically by the Cloud Controller Manager."
    echo "You can check its status with:"
    echo "  kubectl get svc -n ${INGRESS_CONTROLLER_NAMESPACE}"
    echo ""
    echo "Once the EXTERNAL-IP appears, you can view the Load Balancer in OCI Console:"
    echo "  Networking -> Load Balancers"
    
    # Clean up temporary values file
    rm -f ${TRAEFIK_VALUES_FILE}
fi
