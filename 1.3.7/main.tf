# -----------------------------------------------------------------------------
# 1.3.7 - remote_write to long-term storage (Cortex)
#
# One EC2 box running Cortex in single-process mode. A Prometheus somewhere
# else (a kind cluster, another VM) remote_writes into it, and Cortex keeps the
# data long-term on local disk. This is the "give Prometheus a bigger memory"
# half of remote_write.
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

resource "aws_instance" "cortex" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [data.aws_security_group.default.id]
  associate_public_ip_address = true

  tags = {
    Name    = "cortex"
    Role    = "cortex-lts"
    Project = "obs-remote-write-demo"
    Lab     = "1.3.7"
  }

  connection {
    type     = "ssh"
    user     = var.ssh_user
    password = var.ssh_password
    host     = self.public_ip
  }

  # single-process cortex config
  provisioner "file" {
    source      = "${path.module}/templates/cortex.yaml"
    destination = "/tmp/cortex.yaml"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/install_cortex.sh.tftpl", { cortex_version = var.cortex_version })
    destination = "/tmp/install_cortex.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_cortex.sh",
      "sudo bash /tmp/install_cortex.sh",
    ]
  }
}

# After apply, drop a prometheus values file with the real cortex IP baked in,
# so you can `helm ... -f prometheus-values-cortex.rendered.yaml` straight away.
resource "local_file" "prom_values" {
  content = templatefile("${path.module}/templates/prometheus-values-cortex.yaml.tftpl", {
    cortex_ip = aws_instance.cortex.public_ip
  })
  filename = "${path.module}/prometheus-values-cortex.rendered.yaml"
}
