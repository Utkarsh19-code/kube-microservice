data "aws_caller_identity" "current" {}
data "aws_ssm_parameter" "ubuntu_2204" {
  name = "/aws/service/canonical/ubuntu/server/jammy/stable/current/amd64/hvm/ebs-gp2/ami-id"
}
data "aws_vpc" "default" { default = true }
data "aws_subnets" "default" {
  filter { 
    name = "vpc-id" 
    values = [data.aws_vpc.default.id]
   }
}

resource "aws_security_group" "k8s" {
  name = "${var.project_name}-sg"
  description = "K3s learning cluster"
  vpc_id = data.aws_vpc.default.id
}
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.k8s.id
  description = "SSH from operator IP"
  from_port = 22
  to_port = 22
  ip_protocol = "tcp"
  cidr_ipv4 = var.ssh_cidr
}
resource "aws_vpc_security_group_ingress_rule" "frontend" {
  security_group_id = aws_security_group.k8s.id
  description = "Frontend NodePort"
  from_port = 30080
  to_port = 30080
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.k8s.id
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_ecr_repository" "frontend" {
  name = "${var.project_name}/frontend"
  force_delete = true
  image_scanning_configuration { scan_on_push = true }
}
resource "aws_ecr_repository" "product_api" {
  name = "${var.project_name}/product-api"
  force_delete = true
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name
  policy = jsonencode({ rules = [{
    rulePriority = 1, description = "Keep newest 10 images",
    selection = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 },
    action = { type = "expire" }
  }]})
}
resource "aws_ecr_lifecycle_policy" "product_api" {
  repository = aws_ecr_repository.product_api.name
  policy = jsonencode({ rules = [{
    rulePriority = 1, description = "Keep newest 10 images",
    selection = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 },
    action = { type = "expire" }
  }]})
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values = ["sts.amazonaws.com"]
    }
    condition {
      test = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = ["repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"]
    }
  }
}
resource "aws_iam_role" "github_actions" {
  name = var.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}
data "aws_iam_policy_document" "github_policy" {
  statement {
    actions = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability","ecr:BatchGetImage","ecr:CompleteLayerUpload",
      "ecr:DescribeImages","ecr:DescribeRepositories","ecr:InitiateLayerUpload",
      "ecr:ListImages","ecr:PutImage","ecr:UploadLayerPart"
    ]
    resources = [aws_ecr_repository.frontend.arn, aws_ecr_repository.product_api.arn]
  }
  statement {
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:document/AWS-RunShellScript",
      aws_instance.k3s.arn
    ]
  }
  statement {
    actions = ["ssm:GetCommandInvocation"]
    resources = ["*"]
  }
}
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.github_actions_role_name}-policy"
  role = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_policy.json
}

resource "aws_iam_role" "ec2_ssm" {
  name = "${var.project_name}-ec2-ssm"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_ssm.name
}

resource "aws_instance" "k3s" {
  ami = data.aws_ssm_parameter.ubuntu_2204.value
  instance_type = var.instance_type
  subnet_id = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.k8s.id]
  key_name = var.key_name
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.ec2.name
  user_data = file("${path.module}/bootstrap.sh")
  root_block_device { 
    volume_type = "gp2"
    volume_size = var.root_volume_size
    delete_on_termination = true
  }
  tags = { Name = var.project_name }
  depends_on = [aws_iam_role_policy_attachment.ec2_ssm]
}
