# Terraform + GitHub Actions + AWS EC2 + K3s + ECR

This is an end-to-end learning CI/CD project.

Architecture:

GitHub -> GitHub Actions -> OIDC -> AWS IAM
                         -> Docker -> ECR
                         -> SSM -> EC2 -> K3s -> frontend + product-api

## Prerequisites

Install AWS CLI, Terraform >= 1.6 and Git. Have an AWS account and an EC2 key pair in us-east-1.

Verify AWS locally:

    aws sts get-caller-identity
    aws configure get region

## First deployment

1. Create an empty GitHub repository.
2. Copy this repository into it.
3. Edit terraform/terraform.tfvars:

    cp terraform/terraform.tfvars.example terraform/terraform.tfvars

Set key_name, ssh_cidr, and github_repository as OWNER/REPO.

4. Bootstrap infrastructure once locally:

    cd terraform
    terraform init
    terraform fmt -recursive
    terraform validate
    terraform plan
    terraform apply

5. Get outputs:

    terraform output

6. Create GitHub repository variables under Settings -> Secrets and variables -> Actions -> Variables:

    AWS_ROLE_ARN
    EC2_INSTANCE_ID
    ECR_REGISTRY
    FRONTEND_ECR_REPOSITORY
    PRODUCT_API_ECR_REPOSITORY

Use:
    terraform output -raw github_actions_role_arn
    terraform output -raw instance_id
    terraform output -raw frontend_ecr_repository
    terraform output -raw product_api_ecr_repository

ECR_REGISTRY is the hostname before the repository path, e.g.
123456789012.dkr.ecr.us-east-1.amazonaws.com

7. Push main:

    git add .
    git commit -m "Initial CI/CD platform"
    git branch -M main
    git push -u origin main

The deploy workflow builds both images, pushes them to ECR, and uses AWS Systems Manager to deploy them to K3s. No EC2 private key is stored in GitHub.

## Application

Get URL:

    terraform output -raw application_url

Open it in a browser.

Verify on EC2:

    sudo k3s kubectl get nodes
    sudo k3s kubectl get pods -n microservices
    sudo k3s kubectl get svc -n microservices

## Subsequent deployment

Change app/frontend/app.py or app/product-api/app.py, commit and push. GitHub Actions tags images with the Git commit SHA and performs a Kubernetes rollout.

## Why OIDC?

GitHub Actions exchanges a short-lived OIDC token for AWS credentials through STS. Do not create long-lived AWS access keys for GitHub Actions.

## Why SSM?

The deployment workflow uses AWS Systems Manager instead of SSH. The EC2 instance has AmazonSSMManagedInstanceCore, so GitHub does not need an EC2 private key.

## Terraform state

This starter uses local state. For team/production use, move state to a protected remote backend.

## Cost

This deliberately avoids EKS, NAT Gateway, RDS and ALB. EC2/ECR usage can still cost money depending on your AWS Free Tier eligibility. Check AWS billing before and after the lab.

## Destroy

Local:

    cd terraform
    terraform destroy

Or run the manual GitHub Actions Terraform Destroy workflow.

Never run destroy against an account containing unrelated resources without reviewing the plan.
