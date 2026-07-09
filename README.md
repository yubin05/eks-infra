# EKS 개인 프로젝트

AWS EKS 기반 컨테이너 오케스트레이션 실습 프로젝트.
GitHub Actions + Argo CD CI/CD 파이프라인, Prometheus + Grafana 모니터링, HPA 오토스케일링 구성.

---

## 연관 Repository

| 구분 | Repository | 설명 |
|---|---|---|
| 개발자용 | `eks-app` | 프론트엔드 + 백엔드 소스코드, Dockerfile |
| 엔지니어용 | `eks-infra` (이 repo) | Terraform, K8s 매니페스트, Argo CD, 모니터링 |

---

## 아키텍처

```
개발자 코드 푸시 (eks-app)
        ↓
GitHub Actions (이미지 빌드 → ECR 푸시)
        ↓
Argo CD (eks-infra K8s 매니페스트 감지 → EKS 자동 배포)
        ↓
EKS Cluster
├── Frontend (Deployment + Service + HPA)
├── Backend  (Deployment + Service + HPA)
└── ALB Ingress Controller (로드밸런서)
        ↓
모니터링: Prometheus + Grafana / CloudWatch Container Insights
```

---

## 폴더 구조

```
02_EKS_Project/
├── terraform/              # AWS 인프라 프로비저닝 (IaC)
│   ├── ec2.tf              # Bastion EC2
│   ├── iam.tf              # EKS 노드 및 서비스 IAM 역할
│   ├── eks.tf              # EKS 클러스터 + 관리형 노드그룹
│   ├── variables.tf
│   └── outputs.tf
│
├── k8s/                    # Kubernetes 매니페스트
│   ├── backend/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml        # HPA 오토스케일링
│   ├── frontend/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── ingress.yaml        # ALB Ingress (로드밸런서)
│
├── argocd/                 # Argo CD Application 정의
│   ├── application-backend.yaml
│   └── application-frontend.yaml
│
├── monitoring/             # 모니터링 구성
│   ├── prometheus/         # Prometheus 설정
│   └── grafana/            # Grafana 대시보드
│
└── README.md
```

---

## 실습 순서

1. **Terraform** — EC2(Bastion), IAM, EKS 클러스터 + 노드그룹 생성
2. **K8s 매니페스트** — 백엔드/프론트엔드 Deployment, Service, Ingress 작성
3. **CI/CD** — GitHub Actions (빌드/푸시) + Argo CD (자동 배포) 연동
4. **모니터링** — CloudWatch Container Insights, Prometheus + Grafana 구성
5. **HPA** — 오토스케일링 정책 적용 및 부하 테스트

---

## 사용 기술

| 분류 | 기술 |
|---|---|
| 인프라 | AWS EKS, EC2, IAM, ALB |
| IaC | Terraform |
| 컨테이너 | Docker, Amazon ECR |
| CI/CD | GitHub Actions, Argo CD |
| 모니터링 | Prometheus, Grafana, CloudWatch Container Insights |
| 오토스케일링 | HPA (Horizontal Pod Autoscaler) |
