data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.public[0].id
  key_name               = var.bastion_key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  # kubectl/helm 설치, kubeconfig 설정, ALB Controller/ArgoCD 설치까지 부팅 시 자동 실행
  # 실행 로그는 /var/log/user-data.log 에 남음 (SSM으로 확인 가능)
  user_data = templatefile("${path.module}/templates/bastion-userdata.sh.tpl", {
    aws_region              = var.aws_region
    cluster_name            = aws_eks_cluster.main.name
    vpc_id                  = aws_vpc.main.id
    alb_controller_role_arn = aws_iam_role.alb_controller.arn
    infra_repo_url          = var.infra_repo_raw_url
  })

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.alb_controller,
    aws_eks_access_policy_association.bastion_admin,
    aws_security_group_rule.cluster_ingress_from_bastion,
  ]

  tags = {
    Name = "${var.project_name}-bastion"
  }
}
