#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== [1/6] Install base tools ==="
dnf install -y unzip git jq

echo "=== [2/6] Install kubectl ==="
curl -o /usr/local/bin/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-05-12/bin/linux/amd64/kubectl
chmod +x /usr/local/bin/kubectl

echo "=== [3/6] Install helm ==="
curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 /tmp/get_helm.sh
/tmp/get_helm.sh

echo "=== [4/6] Configure kubeconfig ==="
export HOME=/root
aws eks update-kubeconfig --region ${aws_region} --name ${cluster_name}

echo "=== Waiting for worker nodes to be Ready ==="
kubectl wait --for=condition=Ready nodes --all --timeout=600s

echo "=== [5/6] Install AWS Load Balancer Controller ==="
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${cluster_name} \
  --set vpcId=${vpc_id} \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${alb_controller_role_arn}

echo "=== [6/6] Install ArgoCD ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo "=== [best-effort] Register ArgoCD Application from ${infra_repo_url} ==="
kubectl apply -f "${infra_repo_url}/main/argocd/application.yaml" || echo "WARN: ArgoCD Application 등록 실패 - eks-infra 레포 push 여부 확인 후 수동 적용 필요"

echo "=== BOOTSTRAP COMPLETE ==="
