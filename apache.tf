
resource "aws_security_group_rule" "ssh_tunnel_inbound" {
  type              = "ingress"
  security_group_id = data.aws_security_group.apache.id
  from_port         = local.allocated_ssh_port
  to_port           = local.allocated_ssh_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "SSH tunnel vers instance privee sur port ${local.allocated_ssh_port}"
  depends_on        = [data.aws_lambda_invocation.allocate_ssh_port]
}


resource "aws_ssm_document" "configure_apache_iptables" {
  name          = "configure-apache-iptables-${local.allocated_ssh_port}"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Configure iptables NAT on Apache for SSH tunnel port ${local.allocated_ssh_port}"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "configureIptables"
      inputs = {
        runCommand = [
          "echo 'Configuring IP forwarding...'",
          "sysctl -w net.ipv4.ip_forward=1",
          "sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf",
          "echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf",
          "echo 'Installing and enabling iptables-services...'",
          "dnf install -y iptables-services",
          "systemctl enable iptables",
          "echo 'Removing old iptables rules if they exist...'",
          "iptables -t nat -D PREROUTING -p tcp --dport ${local.allocated_ssh_port} -j DNAT --to-destination ${aws_instance.from_my_ami.private_ip}:22 2>/dev/null || true",
          "iptables -t nat -D POSTROUTING -p tcp -d ${aws_instance.from_my_ami.private_ip} --dport 22 -j MASQUERADE 2>/dev/null || true",
          "iptables -D FORWARD -p tcp -d ${aws_instance.from_my_ami.private_ip} --dport 22 -j ACCEPT 2>/dev/null || true",
          "echo 'Adding new iptables rules for SSH tunnel on port ${local.allocated_ssh_port}...'",
          "iptables -t nat -A PREROUTING -p tcp --dport ${local.allocated_ssh_port} -j DNAT --to-destination ${aws_instance.from_my_ami.private_ip}:22",
          "iptables -t nat -A POSTROUTING -p tcp -d ${aws_instance.from_my_ami.private_ip} --dport 22 -j MASQUERADE",
          "iptables -A FORWARD -p tcp -d ${aws_instance.from_my_ami.private_ip} --dport 22 -j ACCEPT",
          "echo 'Saving iptables configuration...'",
          "iptables-save > /etc/sysconfig/iptables",
          "systemctl restart iptables",
          "echo 'iptables configuration complete'"
        ]
      }
    }]
  })
}


resource "aws_ssm_document" "update_apache_config" {
  name          = "update-apache-config"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Update Apache proxy config with new instance IP"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "updateApacheConfig"
      inputs = {
        runCommand = [
          "echo 'Updating Apache proxy configuration...'",
          "NEW_IP=${aws_instance.from_my_ami.private_ip}",
          "CONFIG=$(grep -rl '10.10.0.' /etc/httpd/conf.d/ | head -1)",
          "if [ -z \"$CONFIG\" ]; then echo 'No Apache config found'; exit 1; fi",
          "echo \"Updating Apache config with new IP: $NEW_IP\"",
          "sed -i \"s/10\\.10\\.0\\.[0-9]*/$NEW_IP/g\" $CONFIG",
          "echo 'Testing Apache configuration...'",
          "apachectl configtest",
          "echo 'Reloading Apache service...'",
          "systemctl reload httpd",
          "echo 'Apache configuration update complete'"
        ]
      }
    }]
  })
}

resource "aws_ssm_association" "run_apache_iptables" {
  name = aws_ssm_document.configure_apache_iptables.name

  targets {
    key    = "instanceids"
    values = [var.apache_instance_id]
  }

  depends_on = [aws_instance.from_my_ami]
}

resource "aws_ssm_association" "run_apache_config_update" {
  name = aws_ssm_document.update_apache_config.name

  targets {
    key    = "instanceids"
    values = [var.apache_instance_id]
  }

  depends_on = [aws_instance.from_my_ami]
}