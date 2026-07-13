#!/bin/sh

set -x

# argo_cd_chart_version=9.4.3
argo_cd_chart_version=9.5.22
argo_rollouts_chart_version=2.40.6
cert_manager_chart_version=v1.19.6

kind create cluster \
  --wait 120s \
  --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kargo-advanced
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 31080 # Argo CD dashboard
    hostPort: 31080
  - containerPort: 31081 # Kargo dashboard
    hostPort: 31081
  - containerPort: 31082 # External webhooks server
    hostPort: 31082
  - containerPort: 32080 # dev0 application instance
    hostPort: 32080
  - containerPort: 32081 # test0 application instance
    hostPort: 32081
  - containerPort: 32082 # staging0 application instance
    hostPort: 32082
  - containerPort: 33081 # test1 application instance
    hostPort: 30081
  - containerPort: 33082 # staging1 application instance
    hostPort: 30082
EOF

helm install cert-manager cert-manager \
  --repo https://charts.jetstack.io \
  --version $cert_manager_chart_version \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait

helm install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version $argo_cd_chart_version \
  --namespace argocd \
  --create-namespace \
  --set 'configs.secret.argocdServerAdminPassword=$2a$10$5vm8wXaSdbuff0m9l21JdevzXBzJFPCi8sy6OOnpZMAG.fOXL7jvO' \
  --set dex.enabled=false \
  --set notifications.enabled=false \
  --set server.service.type=NodePort \
  --set server.service.nodePortHttp=31080 \
  --set 'server.extraArgs={--insecure}' \
  --set server.extensions.enabled=true \
  --set 'server.extensions.extensionList[0].name=argo-rollouts' \
  --set 'server.extensions.extensionList[0].env[0].name=EXTENSION_URL' \
  --set 'server.extensions.extensionList[0].env[0].value=https://github.com/argoproj-labs/rollout-extension/releases/download/v0.3.7/extension.tar' \
  --debug \
  --wait
 
helm install argo-rollouts argo-rollouts \
  --repo https://argoproj.github.io/argo-helm \
  --version $argo_rollouts_chart_version \
  --create-namespace \
  --namespace argo-rollouts \
  --wait

# Password is 'admin'
helm install kargo \
  oci://ghcr.io/akuity/kargo-charts/kargo \
  --namespace kargo \
  --create-namespace \
  --set api.service.type=NodePort \
  --set api.service.nodePort=31081 \
  --set 'server.extraArgs={--insecure}' \
  --set api.tls.enabled=false \
  --set api.adminAccount.passwordHash='$2a$10$Zrhhie4vLz5ygtVSaif6o.qN36jgs6vjtMBdM6yrU1FOeiAAMMxOm' \
  --set api.adminAccount.tokenSigningKey=iwishtowashmyirishwristwatch \
  --set externalWebhooksServer.service.type=NodePort \
  --set externalWebhooksServer.service.nodePort=31082 \
  --set externalWebhooksServer.tls.enabled=false \
  --wait

set +x

echo "Run these commands to bootstrap argo proj/app"
echo "argocd login localhost:31080"
echo "argocd proj create -f ./kargo-demo/argocd/appproj.yaml"
echo "argocd appset create ./kargo-demo/argocd/appset.yaml"
echo "Run these commands to boostrap kargo proj"
echo "kargo login http://localhost:31081 --admin"
echo "kargo apply -f ./kargo-demo/kargo"
echo "kargo create repo-credentials github-creds --project kargo-advanced --git --username chartleyit --repo-url https://github.com/chartleyit/kargo-advanced.git"


