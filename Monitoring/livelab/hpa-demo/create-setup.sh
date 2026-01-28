#!/bin/bash
# Copyright (c) 2021, 2022, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

#mkdir ~/test
export PV_ROOT=~/test

chmod 600 ~/.kube/config

kubectl create ns monitoring

kubectl apply -f prometheus/persistence.yaml
kubectl apply -f prometheus/alert-persistence.yaml

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update

helm install prometheus prometheus-community/prometheus --namespace monitoring  --values prometheus/values.yaml --version 17.0.0 --wait


kubectl apply -f grafana/persistence.yaml

kubectl create secret generic grafana-secret --from-literal=username=admin --from-literal=password=12345678 -n monitoring

helm repo add grafana https://grafana.github.io/helm-charts --force-update


helm install  grafana --namespace monitoring --values grafana/values.yaml --version 6.38.6 grafana/grafana --wait
