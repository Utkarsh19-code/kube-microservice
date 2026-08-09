variable "aws_region" { 
    type = string
    default = "us-east-1"
}
variable "project_name" {
    type = string
    default = "k8s-microservices-demo"
}
variable "instance_type" {
    type = string
    default = "t3.micro"
}
variable "key_name" { type = string }
variable "ssh_cidr" {
    type = string
    default = "103.208.68.77/32"
}
variable "root_volume_size" {
    type = number
    default = 10
}
variable "github_repository" {
    type = string
    default = "Utkarsh19-code/kube-microservice"
}

variable "github_branch" {
    type = string
    default = "main"
}
variable "github_actions_role_name" {
    type = string
    default = "github-actions-k8s-microservices"
}
