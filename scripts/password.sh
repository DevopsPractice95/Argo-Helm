#!/usr/bin/env bash
set -euo pipefail
kubectl --context kind-argocd-demo -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode
echo
