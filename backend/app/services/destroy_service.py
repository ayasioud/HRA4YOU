import json
import subprocess
import os
from pathlib import Path
import boto3

from ..core.config import settings


def run_command(cmd: list, cwd: str, env: dict) -> tuple[str, str, int]:
    result = subprocess.run(
        cmd, cwd=cwd, capture_output=True, text=True, check=False, env=env
    )
    return result.stdout, result.stderr, result.returncode


def destroy_instance(instance_name: str) -> dict:

    terraform_dir = settings.terraform_dir
    env = os.environ.copy()
    env["AWS_PROFILE"] = "sopra-sso"

    stdout_all = ""
    stderr_all = ""

    session_kwargs = {}
    if settings.aws_profile:
        session_kwargs["profile_name"] = settings.aws_profile
    session = boto3.Session(**session_kwargs)


    stdout_all += "\n=== Étape 1 : Suppression iptables Apache ===\n"
    ssm = session.client("ssm", region_name=settings.aws_region)

    iptables_script = f"""
TARGET_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values={instance_name}" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text --region {settings.aws_region})

echo "Suppression règles iptables pour $TARGET_IP"


while iptables -t nat -C PREROUTING -p tcp -j DNAT --to-destination $TARGET_IP:22 2>/dev/null; do
    PORT=$(iptables -t nat -S PREROUTING | grep "$TARGET_IP:22" | grep -oP '\\-\\-dport \\K[0-9]+')
    iptables -t nat -D PREROUTING -p tcp --dport $PORT -j DNAT --to-destination $TARGET_IP:22 2>/dev/null || true
done


while iptables -C FORWARD -p tcp -d $TARGET_IP --dport 22 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; do
    iptables -D FORWARD -p tcp -d $TARGET_IP --dport 22 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
done
while iptables -C FORWARD -p tcp -s $TARGET_IP --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; do
    iptables -D FORWARD -p tcp -s $TARGET_IP --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
done


while iptables -t nat -C POSTROUTING -p tcp -d $TARGET_IP --dport 22 -j MASQUERADE 2>/dev/null; do
    iptables -t nat -D POSTROUTING -p tcp -d $TARGET_IP --dport 22 -j MASQUERADE
done

iptables-save > /etc/sysconfig/iptables
echo "iptables nettoyé "
"""

    try:
        response = ssm.send_command(
            InstanceIds=[settings.apache_instance_id],
            DocumentName="AWS-RunShellScript",
            Parameters={"commands": [iptables_script]},
        )
        stdout_all += f"Commande SSM envoyée : {response['Command']['CommandId']} \n"
    except Exception as e:
        stdout_all += f" Erreur iptables : {e}\n"


    stdout_all += "\n=== Étape 2 : Suppression fichier ITERATION Apache ===\n"
    iteration_script = f"""
    
    FILE=$(grep -rl 'ServerName {instance_name.lower()}.cloud.soprahr.com' /etc/httpd/conf.d/ITERATION*.conf 2>/dev/null | head -1)
    if [ -n "$FILE" ]; then
        rm -f "$FILE"
        echo "Fichier supprimé : $FILE "
        apachectl configtest && systemctl reload httpd
    else
        echo "Aucun fichier ITERATION trouvé pour {instance_name} "
    fi
    """


    stdout_all += "\n=== Étape 3 : Suppression Terraform ===\n"

    resources_to_remove = [
        f'aws_instance.from_my_ami["{instance_name}"]',
        f'aws_security_group_rule.ssh_tunnel_inbound["{instance_name}"]',
        f'aws_ssm_document.configure_apache_iptables["{instance_name}"]',
        f'aws_ssm_document.create_apache_iteration["{instance_name}"]',
        f'aws_ssm_association.run_apache_iptables["{instance_name}"]',
        f'aws_ssm_association.run_create_iteration["{instance_name}"]',
        f'aws_ssm_parameter.ec2_user_password["{instance_name}"]',
        f'aws_route53_record.instance["{instance_name}"]',
        f'random_password.ec2_user_password["{instance_name}"]',
        f'data.aws_lambda_invocation.allocate_ssh_port["{instance_name}"]',
    ]

    for resource in resources_to_remove:
        stdout, stderr, code = run_command(
            ['terraform', 'state', 'rm', resource],
            cwd=terraform_dir, env=env
        )
        if 'Successfully' in stdout:
            stdout_all += f" {resource}\n"
        else:
            stdout_all += f" {resource} → déjà supprimé\n"


    stdout_all += "\n=== Étape 4 : Suppression instance EC2 ===\n"
    try:
        ec2 = session.client("ec2", region_name=settings.aws_region)
        instances = ec2.describe_instances(
            Filters=[{"Name": "tag:Name", "Values": [instance_name]},
                     {"Name": "instance-state-name", "Values": ["running", "stopped", "stopping"]}]
        )
        instance_ids = [
            i["InstanceId"]
            for r in instances["Reservations"]
            for i in r["Instances"]
        ]
        if instance_ids:
            ec2.terminate_instances(InstanceIds=instance_ids)
            stdout_all += f"Instance {instance_ids} terminée \n"
        else:
            stdout_all += f"Instance {instance_name} non trouvée dans AWS\n"
    except Exception as e:
        stdout_all += f" Erreur suppression EC2 : {e}\n"


    stdout_all += "\n=== Étape 5 : Suppression port DynamoDB ===\n"
    try:
        dynamodb = session.resource("dynamodb", region_name=settings.aws_region)
        table = dynamodb.Table(settings.ssh_port_counter_table)
        table.delete_item(Key={"counter_id": f"instance#{instance_name}"})
        stdout_all += f"Port DynamoDB supprimé \n"
    except Exception as e:
        stdout_all += f"⚠️ Erreur DynamoDB : {e}\n"


    stdout_all += "\n=== Étape 6 : Suppression Security Group rule ===\n"
    try:
        ec2 = session.client("ec2", region_name=settings.aws_region)


        sgs = ec2.describe_security_groups(
            Filters=[{"Name": "tag:Name", "Values": [settings.apache_sg_name]}]
        )
        apache_sg_id = sgs['SecurityGroups'][0]['GroupId']


        rules = ec2.describe_security_group_rules(
            Filters=[{"Name": "group-id", "Values": [apache_sg_id]}]
        )
        for rule in rules["SecurityGroupRules"]:
            if not rule.get("IsEgress") and instance_name in rule.get("Description", ""):
                ec2.revoke_security_group_ingress(
                    GroupId=apache_sg_id,
                    SecurityGroupRuleIds=[rule["SecurityGroupRuleId"]]
                )
                stdout_all += f"Security Group rule supprimée \n"
    except Exception as e:
        stdout_all += f" Erreur Security Group : {e}\n"


    stdout_all += "\n=== Étape 7 : Suppression SSM Parameter ===\n"
    try:
        ssm = session.client("ssm", region_name=settings.aws_region)
        ssm.delete_parameter(Name=f"/hra4you/ssh/ec2-user-password/{instance_name}")
        stdout_all += f"SSM Parameter supprimé \n"
    except Exception as e:
        stdout_all += f"⚠️ Erreur SSM Parameter : {e}\n"


    stdout_all += "\n=== Étape 8 : Mise à jour tfvars ===\n"
    try:
        tfvars_path = Path(terraform_dir) / settings.terraform_var_file
        existing = json.loads(tfvars_path.read_text(encoding="utf-8"))
        instances = existing.get("instances", {})
        if instance_name in instances:
            del instances[instance_name]
            existing["instances"] = instances
            if existing.get("instance_name") == instance_name:
                existing["instance_name"] = list(instances.keys())[0] if instances else ""
            tfvars_path.write_text(json.dumps(existing, indent=2), encoding="utf-8")
            stdout_all += f"tfvars mis à jour \n"
    except Exception as e:
        stdout_all += f" Erreur tfvars : {e}\n"

    stdout_all += "\n Suppression terminée !\n"

    return {
        "status": "success",
        "message": f"Instance {instance_name} supprimée",
        "stdout": stdout_all,
    }
