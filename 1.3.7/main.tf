# -----------------------------------------------------------------------------
# 1.3.7 - remote_write to long-term storage (Grafana Mimir)
#
# One EC2 box running Mimir in single-process mode. A Prometheus somewhere else
# (a kind cluster, another VM) remote_writes into it, and Mimir keeps the data
# long-term on local disk. This is the "give Prometheus a bigger memory" half of
# remote_write. Mimir is Cortex's successor and the market default today.
# -----------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

# default SG that ships with the default VPC
data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}

# a default subnet to drop the box in (with a public IP)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  subnet_id = tolist(data.aws_subnets.default.ids)[0]
}

resource "aws_instance" "mimir" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [data.aws_security_group.default.id]
  associate_public_ip_address = true

  tags = {
    Name    = "mimir"
    Role    = "mimir-lts"
    Project = "obs-remote-write-demo"
    Lab     = "1.3.7"
  }

  connection {
    type     = "ssh"
    user     = var.ssh_user
    password = var.ssh_password
    host     = self.public_ip
  }

  # single-process mimir config
  provisioner "file" {
    source      = "${path.module}/templates/mimir.yaml"
    destination = "/tmp/mimir.yaml"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/install_mimir.sh.tftpl", { mimir_version = var.mimir_version })
    destination = "/tmp/install_mimir.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_mimir.sh",
      "sudo bash /tmp/install_mimir.sh",
    ]
  }
}

# After apply, drop a prometheus values file with the real mimir IP baked in,
# so you can `helm ... -f prometheus-values-mimir.rendered.yaml` straight away.
resource "local_file" "prom_values" {
  content = templatefile("${path.module}/templates/prometheus-values-mimir.yaml.tftpl", {
    mimir_ip = aws_instance.mimir.public_ip
  })
  filename = "${path.module}/prometheus-values-mimir.rendered.yaml"
}
