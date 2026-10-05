#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::Retries=5 update
apt-get -o Acquire::Retries=5 install -y nginx
cat > /var/www/html/index.html <<'HTML'
<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Terraform Case Study</title><body><h1>Terraform DevOps Case Study</h1><p>Nginx provisioned automatically with Infrastructure as Code.</p></body></html>
HTML
systemctl enable --now nginx
