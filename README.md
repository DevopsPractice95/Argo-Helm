# Local Helm + Argo CD demo

This setup runs Kubernetes in Kind inside a dedicated Colima VM on this Mac.
Argo CD v3.5.3 deploys the official example Helm chart with its image overridden
to NGINX, serving the NGINX welcome page. The Argo CD application is `helm-demo`.

## Open the applications

Run `bash scripts/access.sh` and leave that terminal open:

- Argo CD: https://localhost:8080 (accept the local self-signed certificate)
- Website: http://localhost:8081
- Argo CD username: `admin`
- Get the password: `bash scripts/password.sh`

## Check the deployment

```bash
kubectl --context kind-argocd-demo -n argocd get applications
kubectl --context kind-argocd-demo -n demo get deployments,pods,services
```

Argo CD should report `Synced` and `Healthy`. Argo CD renders the Helm chart
and manages its Kubernetes resources; this does not create a Helm CLI release.

## Project structure

```text
helm/nginx/
  Chart.yaml                 # Chart name, version and app version
  values.yaml                # Shared application defaults
  values.schema.json         # Validate values and catch invalid inputs
  templates/
    _helpers.tpl             # Resource naming helpers
    deployment.yaml          # Pods, probes and resource requests/limits
    service.yaml             # Network access to the pods
environments/
  dev/values.yaml            # Development overrides
  prod/values.yaml           # Example production sizing
argocd/
  project.yaml               # Restrict repositories, namespace and resource kinds
  application-dev.yaml       # Argo CD source and dev values file
manifests/demo-application.yaml # Original bootstrap app (currently deployed)
scripts/
  validate.sh                # Lint and render both environments
  access.sh                  # Local browser access
  password.sh                # Read the initial admin password
vendor/                      # Pinned upstream installation and example reference
```

Helm requires the filename `Chart.yaml` (capital C). Default values belong in
`values.yaml`. Resource names and selectors retain compatibility with the
existing demo so moving to this chart does not require deleting its Deployment.

## Validate and preview changes

```bash
bash scripts/validate.sh
helm template helm-demo helm/nginx -n demo -f environments/dev/values.yaml
```

Edit shared settings in `helm/nginx/values.yaml` and environment-specific settings
in `environments/dev/values.yaml` or `environments/prod/values.yaml`.
The prod file is an example, not a complete production deployment. Real production
needs environment-specific ingress/TLS, availability, monitoring and image policy.
No secrets belong in values files committed to Git.

## Connect this chart to Argo CD

Repository: https://github.com/DevopsPractice95/Argo-Helm.
The development Application tracks `main` and reads `helm/nginx` with dev values.
Push changes to `main` for automatic reconciliation. Apply the configuration:

```bash
kubectl --context kind-argocd-demo create namespace demo --dry-run=client -o yaml | kubectl --context kind-argocd-demo apply -f -
kubectl --context kind-argocd-demo apply -f argocd/project.yaml
kubectl --context kind-argocd-demo apply -f argocd/application-dev.yaml
kubectl --context kind-argocd-demo -n argocd get applications
```

The Application uses `helm/nginx` and loads `../../environments/dev/values.yaml`.
For subsequent dev releases, push chart/values changes to `main`. Use an immutable
commit or release tag in `targetRevision` for controlled releases. Do not reapply the bootstrap manifest after migrating; that
would switch the Application back to the public example. Do not run `helm install`
for the same resources already managed by Argo CD.

## Stop and resume

Stop the access terminal with Ctrl-C. Stop the VM with:

```bash
colima stop --profile argocd-demo
```

Resume with:

```bash
colima start --profile argocd-demo
bash scripts/access.sh
```

The VM uses 4 CPUs, 6 GiB RAM and a 30 GiB data disk. Kubernetes context:
`kind-argocd-demo`. Docker context: `colima-argocd-demo`.
The isolated `.runtime/docker/config.json` avoids stale Docker Desktop helpers.

## Recreate on a fresh machine

```bash
brew install colima docker kind kubectl helm argocd
colima start --profile argocd-demo --cpu 4 --memory 6 --disk 30 --vm-type vz --runtime docker
kind create cluster --name argocd-demo --wait 120s
kubectl --context kind-argocd-demo create namespace argocd
kubectl --context kind-argocd-demo apply --server-side --force-conflicts -n argocd -f vendor/argocd-v3.5.3.yaml
kubectl --context kind-argocd-demo apply -f manifests/demo-application.yaml
```

If an old Docker credential helper is missing, run Kind with `DOCKER_CONFIG`
pointing to a directory containing `config.json` with `{"auths":{}}`, and
`DOCKER_HOST=unix://$HOME/.colima/argocd-demo/docker.sock`.

Reference: https://argo-cd.readthedocs.io/en/stable/getting_started/

## Local DNS workaround

The repo-server pod uses `ndots: 1` and `single-request-reopen` to avoid
intermittent external lookups through the Colima DNS forwarder. Reapply after
reinstalling or upgrading the upstream Argo CD Deployment:

```bash
kubectl --context kind-argocd-demo -n argocd patch deployment argocd-repo-server --patch-file manifests/argocd-repo-server-dns-patch.yaml
```

Development runs three replicas, configured in `environments/dev/values.yaml`.
