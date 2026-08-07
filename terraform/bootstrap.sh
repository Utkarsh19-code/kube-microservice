#!/bin/bash
set -euxo pipefail
exec > >(tee -a /var/log/k8s-microservices-bootstrap.log) 2>&1
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl ca-certificates docker.io awscli
systemctl enable --now docker
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 2G /swapfile || true
  chmod 600 /swapfile || true
  mkswap /swapfile || true
  swapon /swapfile || true
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
fi
curl -sfL https://get.k3s.io | sh -s - --kubelet-arg=fail-swap-on=false
systemctl enable k3s
systemctl restart k3s
until k3s kubectl get nodes >/dev/null 2>&1; do sleep 5; done
echo "K3s ready. GitHub Actions deploys application images."
