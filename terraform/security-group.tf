resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH from trusted CIDR"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_allowed_cidr]
  }

  # Grafana(kubectl port-forward)를 SSM 대신 직접 접속으로 확인하기 위한 임시 포트
  ingress {
    description = "Grafana (kubectl port-forward)"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.bastion_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

# Bastion 보안그룹에서 EKS API 서버(443)로 접근할 수 있도록 클러스터 보안그룹에 인바운드 허용
resource "aws_security_group_rule" "cluster_ingress_from_bastion" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.bastion.id
  description              = "Allow Bastion to reach EKS API server"
}
