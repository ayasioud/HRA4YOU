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


  
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  
  user_data = <<-EOF
#!/bin/bash
set -euo pipefail
LOG=/var/log/user-data.log
exec >"$LOG" 2>&1

REGION="${var.aws_region}"
PARAM_NAME="${var.ssm_param_name}"

echo "[user-data] start"
FLAG="/pk00/.cleanup_done"
CRON_LINE='@reboot sleep 30 && ksh /app/start_env_PK00.sh > /pk00/txt/log/start_env_PK00.log 2>&1'
CRON_USER="ec2-user"
echo "[cleanup] early: disable cron + remove @reboot line ASAP"

systemctl stop crond 2>/dev/null || true
systemctl disable crond 2>/dev/null || true
systemctl mask crond 2>/dev/null || true

# 2) remove @reboot line from ec2-user crontab (persistent)
mkdir -p /root/pk00-cleanup
crontab -u "$CRON_USER" -l > /root/pk00-cleanup/crontab.$${CRON_USER}.bak.$(date +%F-%H%M%S) 2>/dev/null || true
( crontab -u "$CRON_USER" -l 2>/dev/null | grep -Fv "$CRON_LINE" ) | crontab -u "$CRON_USER" - 2>/dev/null || true

echo "[cleanup] early: cron disabled + @reboot removed for $CRON_USER"


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


TNS="/app/oracle/product/19.3.0/dbhome_1/network/admin/tnsnames.ora"


TOKEN=$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)

IP_PRIVATE=""
if [ -n "$TOKEN" ]; then
  IP_PRIVATE=$(curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" \
    "http://169.254.169.254/latest/meta-data/local-ipv4" || true)
fi


if [ -z "$IP_PRIVATE" ]; then
  IP_PRIVATE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}' || true)
fi

echo "[user-data] IP_PRIVATE=$IP_PRIVATE"


if [ -n "$IP_PRIVATE" ] && [ -f "$TNS" ]; then
  sudo -u oracle cp -a "$TNS" "$TNS.bak.$(date +%F-%H%M%S)" || true

 
  sudo -u oracle sed -i "s/(HOST = 127.0.0.1)/(HOST = $IP_PRIVATE)/g" "$TNS"

  echo "[user-data] tnsnames.ora updated"
else
  echo "[user-data] WARN: cannot update tnsnames.ora (missing file or empty IP)"
fi



if [ ! -f "$FLAG" ]; then
  echo "[cleanup] first boot -> running cleanup "

  echo "[cleanup] stopping apps "

  
  [ -x /pk00/tomweb/bin/shutdown.sh ]   && /pk00/tomweb/bin/shutdown.sh   || true
  [ -x /pk00/tombatch/bin/shutdown.sh ] && /pk00/tombatch/bin/shutdown.sh || true
  sleep 10

  
  [ -x /pk00/openhr/bin/stop_openhr.sh ] && (cd /pk00/openhr/bin && ./stop_openhr.sh) || true
  [ -x /pk00/query/bin/stop_query.sh ]   && (cd /pk00/query/bin && ./stop_query.sh)   || true
  sleep 10


  echo "[cleanup] forcing stop if still alive"
  pkill -TERM -f "Dcatalina\.base=/pk00/tomweb"   2>/dev/null || true
  pkill -TERM -f "Dcatalina\.base=/pk00/tombatch" 2>/dev/null || true
  pkill -TERM -f "OpenHRServer"                   2>/dev/null || true
  pkill -TERM -f "QueryServer"                    2>/dev/null || true
  sleep 8

  pkill -KILL -f "Dcatalina\.base=/pk00/tomweb"   2>/dev/null || true
  pkill -KILL -f "Dcatalina\.base=/pk00/tombatch" 2>/dev/null || true
  pkill -KILL -f "OpenHRServer"                   2>/dev/null || true
  pkill -KILL -f "QueryServer"                    2>/dev/null || true

 
  fuser -k -9 /pk00 2>/dev/null || true

  echo "[cleanup] processes after stop:"
  pgrep -af "Dcatalina\.base=/pk00/tomweb|Dcatalina\.base=/pk00/tombatch|OpenHRServer|QueryServer" || true

  
  echo "[cleanup] cleaning folders"
  paths=(
    "/pk00/openhr/logs" "/pk00/openhr/work"
    "/pk00/query/logs"  "/pk00/query/work"
    "/pk00/tomweb/work" "/pk00/tomweb/logs"
    "/pk00/tombatch/work" "/pk00/tombatch/logs"
  )

  for d in "$${paths[@]}"; do
    if [ -d "$d" ]; then
      echo "[cleanup] cleaning $d"
      find "$d" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} 
    else
      echo "[cleanup] skip missing $d"
    fi
  done

  echo "[cleanup] clean-only: NOT starting services."
  echo "[cleanup] when ready: sudo ksh /app/start_env_PK00.sh"

  sync || true
  touch "$FLAG"
  echo "[cleanup] done + flag created: $FLAG"
else
  echo "[cleanup] flag exists -> skip cleanup"
fi

echo "[cleanup] end"
echo "[user-data] end"
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