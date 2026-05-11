
resource "aws_security_group_rule" "ssh_tunnel_inbound" {
  for_each          = local.allocated_ssh_ports
  type              = "ingress"
  security_group_id = data.aws_security_group.apache.id
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "SSH tunnel ${each.key} sur port ${each.value}"
  depends_on        = [data.aws_lambda_invocation.allocate_ssh_port]
}


resource "aws_ssm_document" "configure_apache_iptables" {
  for_each      = local.allocated_ssh_ports
  name          = "configure-apache-iptables-${substr(replace(each.key, "_", "-"), 0, 30)}-${each.value}"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Configure iptables NAT on Apache for SSH tunnel ${each.key} port ${each.value}"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "configureIptables"
      inputs = {
        runCommand = [
          "echo 'Configuring IP forwarding...'",
          "sysctl -w net.ipv4.ip_forward=1",
          "sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf",
          "echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf",
          "sysctl -p >/dev/null 2>&1",
          "",
          "echo 'Installing iptables-services...'",
          "dnf install -y iptables-services 2>/dev/null || yum install -y iptables 2>/dev/null || true",
          "",
          "echo 'Enabling and starting iptables...'",
          "systemctl enable iptables 2>/dev/null || true",
          "systemctl start iptables 2>/dev/null || true",
          "",
          "TARGET_IP=${aws_instance.from_my_ami[each.key].private_ip}",
          "TARGET_PORT=${each.value}",
          "echo 'Cleaning existing DNAT rules for target instance...'",
          "OLD_PORTS=$(iptables -t nat -S PREROUTING | grep -- \"--to-destination $TARGET_IP:22\" | sed -n 's/.*--dport \\\\([0-9]\\\\+\\\\).*/\\\\1/p' | sort -u)",
          "for p in $OLD_PORTS; do iptables -t nat -D PREROUTING -p tcp --dport \"$p\" -j DNAT --to-destination \"$TARGET_IP\":22 2>/dev/null || true; done",
          "",
          "echo 'Removing duplicated FORWARD/POSTROUTING rules if any...'",
          "while iptables -t nat -C POSTROUTING -p tcp -d \"$TARGET_IP\" --dport 22 -j MASQUERADE 2>/dev/null; do iptables -t nat -D POSTROUTING -p tcp -d \"$TARGET_IP\" --dport 22 -j MASQUERADE; done",
          "while iptables -C FORWARD -p tcp -d \"$TARGET_IP\" --dport 22 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; do iptables -D FORWARD -p tcp -d \"$TARGET_IP\" --dport 22 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT; done",
          "while iptables -C FORWARD -p tcp -s \"$TARGET_IP\" --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; do iptables -D FORWARD -p tcp -s \"$TARGET_IP\" --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; done",
          "",
          "echo 'Adding new iptables rules for SSH tunnel on port $TARGET_PORT...'",
          "iptables -t nat -A PREROUTING -p tcp --dport \"$TARGET_PORT\" -j DNAT --to-destination \"$TARGET_IP\":22",
          "iptables -t nat -A POSTROUTING -p tcp -d \"$TARGET_IP\" --dport 22 -j MASQUERADE",
          "iptables -A FORWARD -p tcp -d \"$TARGET_IP\" --dport 22 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT",
          "iptables -A FORWARD -p tcp -s \"$TARGET_IP\" --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT",
          "",
          "echo 'Saving iptables configuration...'",
          "iptables-save > /etc/sysconfig/iptables",
          "",
          "echo 'Restarting iptables to apply rules...'",
          "systemctl restart iptables 2>/dev/null || true",
          "",
          "echo 'Verifying iptables configuration...'",
          "echo '=== NAT Rules ==='",
          "iptables -t nat -L -n -v",
          "echo '=== FORWARD Rules ==='",
          "iptables -L FORWARD -n -v"
        ]
      }
    }]
  })
}


resource "aws_ssm_document" "create_apache_iteration" {
  for_each      = var.instances
  name          = "create-apache-iteration-${substr(replace(each.key, "_", "-"), 0, 30)}"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Create Apache ITERATION config for ${each.key}"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "createIteration"
      inputs = {
        runCommand = [
              "TARGET_IP=${aws_instance.from_my_ami[each.key].private_ip}",
              "echo \"Target IP: $TARGET_IP\"",
              "",
              "# Trouver le prochain numéro d'itération en lisant Apache",
              "MAX=$(ls /etc/httpd/conf.d/ITERATION*.conf 2>/dev/null | sed 's/.*ITERATION\\([0-9]*\\)\\.conf/\\1/' | sort -n | tail -1)",
              "if [ -z \"$MAX\" ]; then NEXT=1; else NEXT=$((MAX+1)); fi",
              "echo \"Prochain numéro : ITERATION$NEXT\"",
              "",
              "# Créer le fichier ITERATION",
              "cat > /etc/httpd/conf.d/ITERATION$NEXT.conf << 'APACHEEOF'",
              "<VirtualHost *:A_CONFIGURER>",
              "ServerName ${each.key}.cloud.soprahr.com",
              "",
              "## TOMBATCH",
              "    ProxyPass /hr-admin-console http://TARGET_IP_PLACEHOLDER:28112/hr-admin-console",
              "    ProxyPassReverse /hr-admin-console http://TARGET_IP_PLACEHOLDER:28112/hr-admin-console",
              "    ProxyPass /hr-online-query http://TARGET_IP_PLACEHOLDER:28112/hr-online-query",
              "    ProxyPassReverse /hr-online-query http://TARGET_IP_PLACEHOLDER:28112/hr-online-query",
              "",
              "## ADDIN EXCEL",
              "    ProxyPass /hr-ws http://TARGET_IP_PLACEHOLDER:28112/hr-ws",
              "    ProxyPassReverse /hr-ws http://TARGET_IP_PLACEHOLDER:28112/hr-ws",
              "    ProxyPass /hr-ws/services/ http://TARGET_IP_PLACEHOLDER:28112/hr-ws/services/",
              "    ProxyPassReverse /hr-ws/services/ http://TARGET_IP_PLACEHOLDER:28112/hr-ws/services/",
              "",
              "## TOMWEB (LEGACY)",
              "    ProxyPass /hr-audit-console http://TARGET_IP_PLACEHOLDER:28016/hr-audit-console",
              "    ProxyPassReverse /hr-audit-console http://TARGET_IP_PLACEHOLDER:28016/hr-audit-console",
              "    ProxyPass /hra-space http://TARGET_IP_PLACEHOLDER:28016/hra-space",
              "    ProxyPassReverse /hra-space http://TARGET_IP_PLACEHOLDER:28016/hra-space",
              "    ProxyPass /hr-dms http://TARGET_IP_PLACEHOLDER:28016/hr-dms",
              "    ProxyPassReverse /hr-dms http://TARGET_IP_PLACEHOLDER:28016/hr-dms",
              "    ProxyPass /hr-portlets http://TARGET_IP_PLACEHOLDER:28016/hr-portlets",
              "    ProxyPassReverse /hr-portlets http://TARGET_IP_PLACEHOLDER:28016/hr-portlets",
              "    ProxyPass /hr-rich-client http://TARGET_IP_PLACEHOLDER:28016/hr-rich-client",
              "    ProxyPassReverse /hr-rich-client http://TARGET_IP_PLACEHOLDER:28016/hr-rich-client",
              "    ProxyPass /hr-self-service http://TARGET_IP_PLACEHOLDER:28016/hr-self-service",
              "    ProxyPassReverse /hr-self-service http://TARGET_IP_PLACEHOLDER:28016/hr-self-service",
              "    ProxyPass /hr-my-reports http://TARGET_IP_PLACEHOLDER:28016/hr-my-reports",
              "    ProxyPassReverse /hr-my-reports http://TARGET_IP_PLACEHOLDER:28016/hr-my-reports",
              "    ProxyPass /hr-configuration-tool-web http://TARGET_IP_PLACEHOLDER:28016/hr-configuration-tool-web",
              "    ProxyPassReverse /hr-configuration-tool-web http://TARGET_IP_PLACEHOLDER:28016/hr-configuration-tool-web",
              "    ProxyPass /hr-configuration-tool-web-smartgwt http://TARGET_IP_PLACEHOLDER:28016/hr-configuration-tool-web-smartgwt",
              "    ProxyPassReverse /hr-configuration-tool-web-smartgwt http://TARGET_IP_PLACEHOLDER:28016/hr-configuration-tool-web-smartgwt",
              "    ProxyPass /hr-payroll-analyzer http://TARGET_IP_PLACEHOLDER:28016/hr-payroll-analyzer",
              "    ProxyPassReverse /hr-payroll-analyzer http://TARGET_IP_PLACEHOLDER:28016/hr-payroll-analyzer",
              "    ProxyPass /hr-digital-files http://TARGET_IP_PLACEHOLDER:28016/hr-digital-files",
              "    ProxyPassReverse /hr-digital-files http://TARGET_IP_PLACEHOLDER:28016/hr-digital-files",
              "    ProxyPass /hr-fctu-gateway http://TARGET_IP_PLACEHOLDER:28016/hr-fctu-gateway",
              "    ProxyPassReverse /hr-fctu-gateway http://TARGET_IP_PLACEHOLDER:28016/hr-fctu-gateway",
              "    ProxyPass /HRManageDocuments http://TARGET_IP_PLACEHOLDER:28016/HRManageDocuments",
              "    ProxyPassReverse /HRManageDocuments http://TARGET_IP_PLACEHOLDER:28016/HRManageDocuments",
              "",
              "## MDL-WEB",
              "    ProxyPass /mdl-web http://TARGET_IP_PLACEHOLDER:28016/mdl-web",
              "    ProxyPassReverse /mdl-web http://TARGET_IP_PLACEHOLDER:28016/mdl-web",
              "",
              "## TA - TEAM PLANNING",
              "    ProxyPass /hr-gta-planning-web http://TARGET_IP_PLACEHOLDER:28016/hr-gta-planning-web",
              "    ProxyPassReverse /hr-gta-planning-web http://TARGET_IP_PLACEHOLDER:28016/hr-gta-planning-web",
              "",
              "## 4YOU",
              "    ProxyPass /app/foryou http://TARGET_IP_PLACEHOLDER:28334/app/foryou",
              "    ProxyPassReverse /app/foryou http://TARGET_IP_PLACEHOLDER:28334/app/foryou",
              "    ProxyPass /theme http://TARGET_IP_PLACEHOLDER:28334/theme",
              "    ProxyPassReverse /theme http://TARGET_IP_PLACEHOLDER:28334/theme",
              "    ProxyPass /space http://TARGET_IP_PLACEHOLDER:28334/space",
              "    ProxyPassReverse /space http://TARGET_IP_PLACEHOLDER:28334/space",
              "    ProxyPass /cxf http://TARGET_IP_PLACEHOLDER:28334/cxf",
              "    ProxyPassReverse /cxf http://TARGET_IP_PLACEHOLDER:28334/cxf",
              "",
              "## EDSN",
              "    ProxyPass /edsn http://TARGET_IP_PLACEHOLDER:28344/edsn",
              "    ProxyPassReverse /edsn http://TARGET_IP_PLACEHOLDER:28344/edsn",
              "    ProxyPass /edsn-admin http://TARGET_IP_PLACEHOLDER:28344/edsn-admin",
              "    ProxyPassReverse /edsn-admin http://TARGET_IP_PLACEHOLDER:28344/edsn-admin",
              "",
              "## EVMEDIA - SADV",
              "    ProxyPass /evm-ij http://TARGET_IP_PLACEHOLDER:28362/evm-ij",
              "    ProxyPassReverse /evm-ij http://TARGET_IP_PLACEHOLDER:28362/evm-ij",
              "    ProxyPass /evm-admin http://TARGET_IP_PLACEHOLDER:28362/evm-admin",
              "    ProxyPassReverse /evm-admin http://TARGET_IP_PLACEHOLDER:28362/evm-admin",
              "",
              "ProxyPreserveHost On",
              "ProxyRequests Off",
              "Header edit Location \"http:\" \"https:\"",
              "ErrorLog logs/ITERATION$NEXT-log",
              "CustomLog logs/ITERATION$NEXT-access_log combined",
              "</VirtualHost>",
              "APACHEEOF",
              "",
              "# Remplacer TARGET_IP_PLACEHOLDER par la vraie IP",
              "sed -i \"s/TARGET_IP_PLACEHOLDER/$TARGET_IP/g\" /etc/httpd/conf.d/ITERATION$NEXT.conf",
              "",
              "echo \"ITERATION$NEXT.conf créé avec IP $TARGET_IP\"",
              "echo \"Port à configurer manuellement dans <VirtualHost *:A_CONFIGURER>\""
]
      }
    }]
  })

  depends_on = [data.aws_lambda_invocation.allocate_ssh_port]
}

resource "aws_ssm_association" "run_create_iteration" {
  for_each = aws_ssm_document.create_apache_iteration
  name     = each.value.name

  targets {
    key    = "instanceids"
    values = [var.apache_instance_id]
  }

  depends_on = [aws_instance.from_my_ami, aws_ssm_document.create_apache_iteration]
}



resource "aws_ssm_association" "run_apache_iptables" {
  for_each = aws_ssm_document.configure_apache_iptables
  name     = each.value.name

  targets {
    key    = "instanceids"
    values = [var.apache_instance_id]
  }

  depends_on = [aws_instance.from_my_ami, aws_security_group_rule.ssh_tunnel_inbound]
}


