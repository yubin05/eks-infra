output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "eks_cluster_certificate_authority" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}

output "eks_node_group_name" {
  value = aws_eks_node_group.main.node_group_name
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "alb_controller_role_arn" {
  description = "aws-load-balancer-controller ServiceAccount에 어노테이션으로 넣을 IAM Role ARN"
  value       = aws_iam_role.alb_controller.arn
}

output "ecr_backend_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repository_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "github_actions_access_key_id" {
  description = "GitHub repo secret AWS_ACCESS_KEY_ID 에 등록"
  value       = aws_iam_access_key.github_actions.id
}

output "github_actions_secret_access_key" {
  description = "GitHub repo secret AWS_SECRET_ACCESS_KEY 에 등록"
  value       = aws_iam_access_key.github_actions.secret
  sensitive   = true
}
