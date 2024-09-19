packer {
  required_version = ">= 1.5.1"
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = "~> 1"
    }
  }
}

variable "hcloud_token" {
  type = string
}

variable "hcloud_location" {
  type    = string
  default = "nbg1"
}

variable "github_branch" {
  type    = string
  default = "dev"
}

variable "version" {
  type    = string
  default = "dev"
}

variable "build_identifier" {
  type    = string
}

variable "instance_image" {
  type    = string
  default = "ubuntu-22.04"
}

variable "instance_type" {
  type    = string
  default = "cx22"
}

variable "snapshot_name" {
  type    = string
}

locals {
  build_labels = {
    "name"                 = "flux-worker"
    "os-flavor"            = "ubuntu"
    "packer.io/build.id"   = "${uuidv4()}"
    "packer.io/build.time" = "{{timestamp}}"
    "packer.io/version"    = "{{packer_version}}"
    "branch"               = var.github_branch
    "version"              = var.version
  }
}

source "hcloud" "ubuntu" {
  token         = var.hcloud_token
  image         = var.instance_image
  location      = var.hcloud_location

  server_type   = var.instance_type
  server_labels = {
    build = var.build_identifier
  }

  ssh_username  = "root"
  ssh_keys_labels = {
    build = var.build_identifier
  }

  snapshot_name   = var.snapshot_name
  snapshot_labels = local.build_labels
}

build {
  sources = [
    "source.hcloud.ubuntu"
  ]

  provisioner "file" {
    source      = "src/flux-worker/wait-for-kubernetes"
    destination = "/usr/local/bin/wait-for-kubernetes"
  }

  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get upgrade -y",
      "apt-get install -y curl ca-certificates",
      "chmod +x /usr/local/bin/wait-for-kubernetes",
      "install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
      "chmod a+r /etc/apt/keyrings/docker.asc",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "apt-get update",
      "apt-get install -y docker-ce",
      "curl -sfL https://get.k3s.io | sh -",
      "k3s-killall.sh",
      "rm -rf /var/lib/rancher/k3s",
      "systemctl disable --now k3s.service",
      "curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null",
      "apt-get install apt-transport-https --yes",
      "echo \"deb [signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main\" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list > /dev/null",
      "apt-get update",
      "apt-get install helm",
      "curl -L https://github.com/derailed/k9s/releases/download/v0.32.4/k9s_linux_amd64.deb -o k9s.deb && dpkg -i k9s.deb && rm k9s.deb",
      "curl -s https://raw.githubusercontent.com/fluxcd/flux2/main/install/flux.sh | sudo bash",
      "cloud-init clean --logs --machine-id --seed --configs all",
      "rm -rf /run/cloud-init/*",
      "rm -rf /var/lib/cloud/*",
      "apt-get -y autopurge",
      "apt-get -y clean",
      "rm -rf /var/lib/apt/lists/*",
      "journalctl --flush",
      "journalctl --rotate --vacuum-time=0",
      "find /var/log -type f -exec truncate --size 0 {} \\;",
      "find /var/log -type f -name '*.[1-9]' -delete",
      "find /var/log -type f -name '*.gz' -delete",
      "rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub",
      "dd if=/dev/zero of=/zero bs=4M || true",
      "sync",
      "rm -f /zero"
    ]
  }
}
