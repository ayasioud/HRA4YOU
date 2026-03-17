data "aws_ami" "my_ami" {
  filter {
    name   = "image-id"
    values = ["ami-0f8f8adb7e6742c4a"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
////lina bech yakhou il ip automatiquenement 
data "http" "myip" {
  url = "https://checkip.amazonaws.com/"
}
locals {
  my_ip_cidr = "${chomp(data.http.myip.response_body)}/32"
}


data "aws_lambda_invocation" "allocate_ssh_port" {
  function_name = aws_lambda_function.allocate_port.function_name
  input         = jsonencode({ version = data.archive_file.lambda_code.output_base64sha256 })
  depends_on    = [aws_lambda_function.allocate_port]
}

locals {
  port_response      = jsondecode(data.aws_lambda_invocation.allocate_ssh_port.result)
  allocated_ssh_port = try(local.port_response.port, jsondecode(local.port_response.body).port)
}

data "aws_vpc" "target" {
  filter {
    name   = "tag:Name"
    values = [var.target_vpc_name]
  }
}

data "aws_subnets" "target" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.target.id]
  }
}
locals {
  chosen_subnet_id = data.aws_subnets.target.ids[0]
}
resource "aws_key_pair" "hra4you" {
  key_name   = "hra4you-key"
  public_key = file("${path.module}/keys/hra4you.pub")
}
data "aws_security_group" "apache"{
  filter {
    name = "tag:Name"
    values = [var.apache_sg_name]
  }
  vpc_id = data.aws_vpc.target.id
}

resource "aws_security_group" "ssh_access" {
  name        = "ssh-access"
  description = "Allow SSH"
  vpc_id      = data.aws_vpc.target.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group_rule" "http_from_apache_sg" {
  type              = "ingress"
  security_group_id = aws_security_group.ssh_access.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  source_security_group_id = data.aws_security_group.apache.id
  description       = "HTTP from Apache SG"

}
resource "aws_security_group_rule" "https_from_apache_sg" {
  type              = "ingress"
  security_group_id = aws_security_group.ssh_access.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  source_security_group_id = data.aws_security_group.apache.id
  description       = "HTTPS from Apache SG"

}

resource "aws_security_group_rule" "ssh_from_apache_sg" {
  type              = "ingress"
  security_group_id = aws_security_group.ssh_access.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  source_security_group_id = data.aws_security_group.apache.id
  description              = "SSH from Apache SG"
}
data "aws_route53_zone" "main" {
  name         = "cloud.soprahr.com."
  private_zone = false
}
data "aws_instance" "apache" {
  instance_id = var.apache_instance_id
}


resource "aws_route53_record" "app" {
  zone_id    = data.aws_route53_zone.main.zone_id
  name       = "hra4you.cloud.soprahr.com"
  type       = "A"
  ttl        = 60
  records    = [data.aws_instance.apache.public_ip]
  
}
resource "aws_iam_role_policy_attachment" "attach_ssm_core" {
  role = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  
}

resource "aws_instance" "from_my_ami" {
  ami           = data.aws_ami.my_ami.id
  instance_type = "t2.2xlarge"

  subnet_id                   = local.chosen_subnet_id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.ssh_access.id]
  key_name                    = aws_key_pair.hra4you.key_name
  user_data_replace_on_change = true



  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name


 user_data = <<-EOF
#!/bin/bash
set -euo pipefail
LOG=/var/log/user-data.log
exec >"$LOG" 2>&1

echo "[user-data] start $(date -Is)"

REGION="${var.aws_region}"
PARAM_NAME="${var.ssm_param_name}"
VPC_CIDR="${var.vpc_cidr}"

CRON_USER="ec2-user"
FLAG="/pk00/.cleanup_done"
CRON_LINE='@reboot sleep 30 && ksh /app/start_env_PK00.sh > /pk00/txt/log/start_env_PK00.log 2>&1'


echo "[cleanup] disable cron early + remove @reboot"
systemctl stop crond 2>/dev/null || true
systemctl disable crond 2>/dev/null || true
systemctl mask crond 2>/dev/null || true

mkdir -p /root/pk00-cleanup
crontab -u "$CRON_USER" -l > "/root/pk00-cleanup/crontab.$CRON_USER.bak.$(date +%F-%H%M%S)" 2>/dev/null || true
( crontab -u "$CRON_USER" -l 2>/dev/null | grep -Fv "$CRON_LINE" ) | crontab -u "$CRON_USER" - 2>/dev/null || true


echo "[ssh] configure sshd to allow password auth"

cp -a /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%F-%H%M%S)" || true

if grep -qE '^[# ]*PubkeyAuthentication' /etc/ssh/sshd_config; then
  sed -i 's/^[# ]*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
else
  echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config
fi

if grep -qE '^[# ]*PasswordAuthentication' /etc/ssh/sshd_config; then
  sed -i 's/^[# ]*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
else
  echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
fi

if grep -qE '^[# ]*UsePAM' /etc/ssh/sshd_config; then
  sed -i 's/^[# ]*UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
else
  echo 'UsePAM yes' >> /etc/ssh/sshd_config
fi

sed -i '/^[# ]*AuthenticationMethods\b/d' /etc/ssh/sshd_config
sed -i '/^[# ]*KbdInteractiveAuthentication\b/d' /etc/ssh/sshd_config
sed -i '/^[# ]*ChallengeResponseAuthentication\b/d' /etc/ssh/sshd_config
printf '\nKbdInteractiveAuthentication yes\nChallengeResponseAuthentication yes\n' >> /etc/ssh/sshd_config

echo "[ssh] ensure ec2-user is UNLOCKED (fix LK issue)"
passwd -u ec2-user 2>/dev/null || usermod -U ec2-user || true

# IMPORTANT (AL2023 / PAM): force bash instead of ksh
usermod -s /bin/bash ec2-user 2>/dev/null || true

echo "[pw] setting ec2-user password from Terraform value"

PASS='${random_password.ec2_user_password.result}'
echo "ec2-user:$PASS" | chpasswd
passwd -u ec2-user 2>/dev/null || usermod -U ec2-user || true
chage -M 99999 -m 0 -W 7 ec2-user || true
echo "[pw] password set "


if sshd -t; then
  systemctl restart sshd
  systemctl enable sshd
  echo "[ssh] sshd restarted "
else
  echo "[ssh] ERROR: sshd config invalid"
fi

echo "[ssh] effective:"
sshd -T | egrep -i 'usepam|passwordauthentication|kbdinteractiveauthentication|challengeresponseauthentication|authenticationmethods' || true
echo "[ssh] user status:"
passwd -S ec2-user || true
echo "[ssh] user shell:"
getent passwd ec2-user || true


TOKEN="$(curl -fsS -m 2 -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)"

IP_PRIVATE=""
if [ -n "$TOKEN" ]; then
  IP_PRIVATE="$(curl -fsS -m 2 -H "X-aws-ec2-metadata-token: $TOKEN" \
    "http://169.254.169.254/latest/meta-data/local-ipv4" || true)"
fi

if [ -z "$IP_PRIVATE" ]; then
  IP_PRIVATE="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}' || true)"
fi
echo "[net] IP_PRIVATE=$IP_PRIVATE"


echo "[iptables] applying rules"


if ! command -v iptables >/dev/null 2>&1; then
  if command -v dnf >/dev/null 2>&1; then
    dnf -y install iptables-nft >/dev/null 2>&1 || true
  elif command -v yum >/dev/null 2>&1; then
    yum -y install iptables >/dev/null 2>&1 || true
  fi
fi


if command -v iptables >/dev/null 2>&1; then
  iptables -P INPUT ACCEPT 2>/dev/null || true
  iptables -F || true

  iptables -A INPUT -i lo -j ACCEPT
  iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

  iptables -A INPUT -p tcp -s "$VPC_CIDR" --dport 22  -j ACCEPT
  iptables -A INPUT -p tcp -s "$VPC_CIDR" --dport 80  -j ACCEPT
  iptables -A INPUT -p tcp -s "$VPC_CIDR" --dport 443 -j ACCEPT

  iptables -A INPUT -j DROP
  iptables -P INPUT DROP 2>/dev/null || true

  iptables-save > /etc/sysconfig/iptables || true
  echo "[iptables] done "
else
  echo "[iptables] WARN: iptables not available even after install attempt"
fi


TNS="/app/oracle/product/19.3.0/dbhome_1/network/admin/tnsnames.ora"
if [ -n "$IP_PRIVATE" ] && [ -f "$TNS" ]; then
  sudo -u oracle cp -a "$TNS" "$TNS.bak.$(date +%F-%H%M%S)" || true
  sudo -u oracle sed -i "s/(HOST = 127.0.0.1)/(HOST = $IP_PRIVATE)/g" "$TNS"
  echo "[tns] updated "
else
  echo "[tns] skip (missing file or empty IP)"
fi


if [ ! -f "$FLAG" ]; then
  echo "[cleanup] first boot -> cleaning logs/work only"

  [ -x /pk00/tomweb/bin/shutdown.sh ]   && /pk00/tomweb/bin/shutdown.sh   || true
  [ -x /pk00/tombatch/bin/shutdown.sh ] && /pk00/tombatch/bin/shutdown.sh || true
  sleep 10

  [ -x /pk00/openhr/bin/stop_openhr.sh ] && (cd /pk00/openhr/bin && ./stop_openhr.sh) || true
  [ -x /pk00/query/bin/stop_query.sh ]   && (cd /pk00/query/bin && ./stop_query.sh)   || true
  sleep 10

  pkill -TERM -f "Dcatalina\.base=/pk00/tomweb"   2>/dev/null || true
  pkill -TERM -f "Dcatalina\.base=/pk00/tombatch" 2>/dev/null || true
  pkill -TERM -f "OpenHRServer"                   2>/dev/null || true
  pkill -TERM -f "QueryServer"                    2>/dev/null || true
  sleep 8
  pkill -KILL -f "Dcatalina\.base=/pk00/tomweb"   2>/dev/null || true
  pkill -KILL -f "Dcatalina\.base=/pk00/tombatch" 2>/dev/null || true
  pkill -KILL -f "OpenHRServer"                   2>/dev/null || true
  pkill -KILL -f "QueryServer"                    2>/dev/null || true

  echo "[cleanup] cleaning folders (preserve ownership)"
  paths=(
    "/pk00/openhr/logs" "/pk00/openhr/work"
    "/pk00/query/logs"  "/pk00/query/work"
    "/pk00/tomweb/work" "/pk00/tomweb/logs"
    "/pk00/tombatch/work" "/pk00/tombatch/logs"
  )
  for d in "$${paths[@]}"; do
    if [ -d "$d" ]; then
      # Sauvegarder owner et group AVANT suppression
      OWNER="$(stat -c '%U' "$d")"
      GROUP="$(stat -c '%G' "$d")"
      PERMS="$(stat -c '%a' "$d")"
      
      # Vider le contenu
      find "$d" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + || true
      
      # Restaurer owner + group + permissions
      chown "$OWNER:$GROUP" "$d" || true
      chmod "$PERMS" "$d" || true
      
      echo "[cleanup] $d vidé -> owner=$OWNER group=$GROUP "
    fi
  done

  echo "[cleanup] done "
  touch "$FLAG"
fi

echo "[user-data] end $(date -Is)"
EOF
  tags = {
    Name = var.instance_name
  }
}

output "private_ip" {
  value = aws_instance.from_my_ami.private_ip
}

output "instance_id" {
  value = aws_instance.from_my_ami.id
}

output "allocated_ssh_port" {
  value       = local.allocated_ssh_port
  description = "Port SSH alloué pour accéder à l'instance via Apache"
}

output "ssh_connection_command" {
  value       = "ssh -p ${local.allocated_ssh_port} ec2-user@${var.apache_private_ip}"
  description = "Commande SSH pour se connecter à l'instance"
}