#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== [1/8] Install base tools ==="
dnf install -y unzip git jq

echo "=== [2/8] Install kubectl ==="
curl -o /usr/local/bin/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-05-12/bin/linux/amd64/kubectl
chmod +x /usr/local/bin/kubectl

echo "=== [3/8] Install helm ==="
curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 /tmp/get_helm.sh
/tmp/get_helm.sh

echo "=== [4/8] Configure kubeconfig ==="
aws eks update-kubeconfig --region ${aws_region} --name ${cluster_name}
# root뿐 아니라 ec2-user로 접속했을 때도 별도 export 없이 kubectl이 바로 되도록 동일하게 설정
sudo -u ec2-user aws eks update-kubeconfig --region ${aws_region} --name ${cluster_name}

echo "=== Waiting for worker nodes to be Ready ==="
kubectl wait --for=condition=Ready nodes --all --timeout=600s

echo "=== [best-effort] Install metrics-server (for HPA) ==="
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml || echo "WARN: metrics-server 설치 실패 - 수동 설치 필요"

echo "=== [5/8] Install AWS Load Balancer Controller ==="
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${cluster_name} \
  --set vpcId=${vpc_id} \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${alb_controller_role_arn}

echo "=== Waiting for AWS Load Balancer Controller webhook to be ready ==="
kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=300s
kubectl wait --for=jsonpath='{.subsets[0].addresses}' endpoints/aws-load-balancer-webhook-service -n kube-system --timeout=180s

echo "=== [6/8] Install ArgoCD ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo "=== [best-effort] Register ArgoCD Application from ${infra_repo_url} ==="
kubectl apply -f "${infra_repo_url}/main/argocd/application.yaml" || echo "WARN: ArgoCD Application 등록 실패 - eks-infra 레포 push 여부 확인 후 수동 적용 필요"

echo "=== [7/8] Install CloudWatch Container Insights (best-effort) ==="
(
  kubectl create namespace amazon-cloudwatch --dry-run=client -o yaml | kubectl apply -f -
  curl -s https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml \
    | sed -e "s/{{cluster_name}}/${cluster_name}/" \
          -e "s/{{region_name}}/${aws_region}/" \
          -e 's/{{http_server_toggle}}/"On"/' \
          -e 's/{{http_server_port}}/"2020"/' \
          -e 's/{{read_from_head}}/"Off"/' \
          -e 's/{{read_from_tail}}/"On"/' \
    | kubectl apply -f -
) || echo "WARN: CloudWatch Container Insights 설치 실패 - 수동 설치 필요"

echo "=== [8/8] Install Prometheus + Grafana (best-effort) ==="
(
  kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  curl -s -o /tmp/prometheus-values.yaml "${infra_repo_url}/main/monitoring/prometheus/values.yaml"
  helm upgrade --install prom-stack prometheus-community/kube-prometheus-stack \
    -n monitoring \
    -f /tmp/prometheus-values.yaml \
    --timeout 20m
) || echo "WARN: Prometheus/Grafana 설치 실패 - 수동 설치 필요"

echo "=== BOOTSTRAP COMPLETE ==="
