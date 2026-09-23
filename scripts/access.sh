#!/usr/bin/env bash
set -euo pipefail
kubectl --context kind-argocd-demo -n argocd port-forward svc/argocd-server 8080:443 &
argo_pid=$!
trap 'kill "$argo_pid" 2>/dev/null || true' EXIT
echo 'Argo CD: https://localhost:8080 (username: admin)'
echo 'Demo: http://localhost:8081'
kubectl --context kind-argocd-demo -n demo port-forward svc/helm-demo-helm-guestbook 8081:80
