# -----------------------------------------------------------------------------
# 1.3.6 - remote_write demo
#
# Three t3.small spot boxes in the default VPC:
#   node-exporter  -> just runs node_exporter (:9100)
#   prom-server-A  -> scrapes node-exporter, then remote_writes everything to B
#   prom-server-B  -> central Prometheus, receives A's remote_write
#
# The whole point of the lab is that last hop: A collects locally and pushes
# its samples out to B instead of B having to reach in and scrape.
# -----------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

# default SG that ships with the default VPC
data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}

# grab the default subnets so we can drop the boxes somewhere with a public IP
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  subnet_id = tolist(data.aws_subnets.default.ids)[0]

  # reused on every instance
  common_tags = {
    Project = "obs-remote-write-demo"
    Lab     = "1.3.6"
  }
}

# ------------------------------- node-exporter -------------------------------
resource "aws_instance" "node_exporter" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [data.aws_security_group.default.id]
  associate_public_ip_address = true

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type = "one-time"
    }
  }

  tags = merge(local.common_tags, {
    Name = "node-exporter"
    Role = "node-exporter"
  })

  connection {
    type     = "ssh"
    user     = var.ssh_user
    password = var.ssh_password
    host     = self.public_ip
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/install_node_exporter.sh.tftpl", { ne_version = var.node_exporter_version })
    destination = "/tmp/install_node_exporter.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_node_exporter.sh",
      "sudo bash /tmp/install_node_exporter.sh",
    ]
  }
}

# ------------------------------- prom-server-B -------------------------------
# Bring B up first - it is the remote_write receiver, so it needs to be
# listening before A starts pushing.
resource "aws_instance" "prom_b" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [data.aws_security_group.default.id]
  associate_public_ip_address = true

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type = "one-time"
    }
  }

  tags = merge(local.common_tags, {
    Name = "prom-server-B"
    Role = "prometheus-receiver"
  })

  connection {
    type     = "ssh"
    user     = var.ssh_user
    password = var.ssh_password
    host     = self.public_ip
  }

  # B just scrapes itself - everything else arrives over remote_write
  provisioner "file" {
    content = templatefile("${path.module}/templates/prometheus_b.yml.tftpl", {
      self_ip = self.private_ip
    })
    destination = "/tmp/prometheus.yml"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/install_prometheus.sh.tftpl", { prom_version = var.prometheus_version })
    destination = "/tmp/install_prometheus.sh"
  }

  # the "receiver" flag flips on --web.enable-remote-write-receiver
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_prometheus.sh",
      "sudo bash /tmp/install_prometheus.sh receiver",
    ]
  }
}

# ------------------------------- prom-server-A -------------------------------
resource "aws_instance" "prom_a" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [data.aws_security_group.default.id]
  associate_public_ip_address = true

  # A needs the node-exporter to scrape and B to push to, so stand it up last
  depends_on = [aws_instance.node_exporter, aws_instance.prom_b]

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type = "one-time"
    }
  }

  tags = merge(local.common_tags, {
    Name = "prom-server-A"
    Role = "prometheus-forwarder"
  })

  connection {
    type     = "ssh"
    user     = var.ssh_user
    password = var.ssh_password
    host     = self.public_ip
  }

  # A scrapes node-exporter + itself, and remote_writes it all to B
  provisioner "file" {
    content = templatefile("${path.module}/templates/prometheus_a.yml.tftpl", {
      self_ip          = self.private_ip
      node_exporter_ip = aws_instance.node_exporter.private_ip
      remote_write_ip  = aws_instance.prom_b.private_ip
    })
    destination = "/tmp/prometheus.yml"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/install_prometheus.sh.tftpl", { prom_version = var.prometheus_version })
    destination = "/tmp/install_prometheus.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_prometheus.sh",
      "sudo bash /tmp/install_prometheus.sh",
    ]
  }
}
