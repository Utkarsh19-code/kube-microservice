output "instance_id" { value = aws_instance.k3s.id }
output "public_ip" { value = aws_instance.k3s.public_ip }
output "application_url" { value = "http://${aws_instance.k3s.public_ip}:30080" }
output "frontend_ecr_repository" { value = aws_ecr_repository.frontend.repository_url }
output "product_api_ecr_repository" { value = aws_ecr_repository.product_api.repository_url }
output "github_actions_role_arn" { value = aws_iam_role.github_actions.arn }
output "github_oidc_subject" {
  value = "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"
}
