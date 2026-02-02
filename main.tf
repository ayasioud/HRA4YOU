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

data "aws_vpc" "default" {
  default = true
}
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_key_pair" "hra4you" {
  key_name   = "hra4you-key"
  public_key = file("${path.module}/keys/hra4you.pub")
}


resource "aws_security_group" "ssh_access" {
  name        = "ssh-access"
  description = "Allow SSH"
  vpc_id      = data.aws_vpc.default.id



  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group_rule" "ssh_from_my_ip" {
  type              = "ingress"
  security_group_id = aws_security_group.ssh_access.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [local.my_ip_cidr]
  description       = "SSH from my IP"
}


resource "aws_instance" "from_my_ami" {
  ami           = data.aws_ami.my_ami.id
  instance_type = "t2.2xlarge"

  subnet_id                   = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh_access.id]
  key_name                    = aws_key_pair.hra4you.key_name
  user_data_replace_on_change = true


  #  AJOUT: IAM role pour lire SSM
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  #  AJOUT: au boot, récupérer mdp depuis SSM et activer SSH password
  user_data = <<-EOF
#!/bin/bash
set -euo pipefail
LOG=/var/log/user-data.log
exec >"$LOG" 2>&1

REGION="${var.aws_region}"
PARAM_NAME="${var.ssm_param_name}"

echo "[user-data] start"

cp -a /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%F-%H%M%S) || true

grep -qE '^[# ]*PasswordAuthentication' /etc/ssh/sshd_config \
  && sed -i 's/^[# ]*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
  || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config

grep -qE '^[# ]*UsePAM' /etc/ssh/sshd_config \
  && sed -i 's/^[# ]*UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config \
  || echo 'UsePAM yes' >> /etc/ssh/sshd_config


sed -i '/^[# ]*KbdInteractiveAuthentication\b/d' /etc/ssh/sshd_config
sed -i '/^[# ]*ChallengeResponseAuthentication\b/d' /etc/ssh/sshd_config
printf '\nKbdInteractiveAuthentication yes\nChallengeResponseAuthentication yes\n' >> /etc/ssh/sshd_config

if ls /etc/yum.repos.d/*elastic* >/dev/null 2>&1; then
  echo "[user-data] fixing elastic repos"
  # option A: désactiver complètement
  sed -i 's/^enabled=1/enabled=0/g' /etc/yum.repos.d/*elastic* || true
  
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "[user-data] installing awscli v2 from zip"
  cd /tmp
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  ./aws/install --update
fi

if command -v aws >/dev/null 2>&1; then
  PASS="$(aws ssm get-parameter --name "$PARAM_NAME" --with-decryption --query 'Parameter.Value' --output text --region "$REGION" 2>/dev/null || true)"
  if [ -n "$PASS" ]; then
    echo "ec2-user:$PASS" | chpasswd
    passwd -u ec2-user 2>/dev/null || usermod -U ec2-user || true
    chage -M 99999 -m 0 -W 7 ec2-user || true
    echo "[user-data] password set from SSM and user unlocked"
  else
    echo "[user-data] WARN: cannot read password from SSM"
  fi
else
  echo "[user-data] WARN: awscli not installed; cannot read SSM password"
fi

if sshd -t; then
  systemctl restart sshd
  systemctl enable sshd
  echo "[user-data] sshd restarted"
else
  echo "[user-data] ERROR: sshd config invalid"
fi

# --- PATCH tnsnames.ora: remplacer 127.0.0.1 par l'IP de l'instance ---
TNS="/app/oracle/product/19.3.0/dbhome_1/network/admin/tnsnames.ora"

# 1) Récupérer l'IP privée de l'instance (IMDSv2)
TOKEN=$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)

IP_PRIVATE=""
if [ -n "$TOKEN" ]; then
  IP_PRIVATE=$(curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" \
    "http://169.254.169.254/latest/meta-data/local-ipv4" || true)
fi

# Fallback si IMDS désactivé/bloqué
if [ -z "$IP_PRIVATE" ]; then
  IP_PRIVATE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}' || true)
fi

echo "[user-data] IP_PRIVATE=$IP_PRIVATE"

# 2) Modifier le fichier en tant que oracle
if [ -n "$IP_PRIVATE" ] && [ -f "$TNS" ]; then
  sudo -u oracle cp -a "$TNS" "$TNS.bak.$(date +%F-%H%M%S)" || true

  # Remplace uniquement le cas 127.0.0.1 (idempotent: si déjà remplacé, ça ne casse rien)
  sudo -u oracle sed -i "s/(HOST = 127.0.0.1)/(HOST = $IP_PRIVATE)/g" "$TNS"

  echo "[user-data] tnsnames.ora updated"
else
  echo "[user-data] WARN: cannot update tnsnames.ora (missing file or empty IP)"
fi



echo "[user-data] done"

EOF
  tags = {
    Name = "hra4you-ec2-from-ami"
  }
}

output "public_ip" {
  value = aws_instance.from_my_ami.public_ip
}

output "instance_id" {
  value = aws_instance.from_my_ami.id
}
