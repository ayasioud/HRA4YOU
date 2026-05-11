import json
import subprocess
import threading
import os
from pathlib import Path
import boto3

from ..core.config import settings
from ..schemas.instance import EC2CreateRequest

terraform_lock = threading.Lock()


def build_instance_payload(payload: EC2CreateRequest) -> dict:
    return {
        "image_id": payload.image_id,
        "instance_type": payload.instance_type,
        "storage_size": payload.storage_size,
        "created_by": payload.created_by,
        "owner_agency": payload.owner_agency,
    }


def read_existing_instances(tfvars_path: Path) -> dict:
    if not tfvars_path.exists():
        return {}
    try:
        existing = json.loads(tfvars_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}
    instances = {}
    raw_instances = existing.get("instances")
    if isinstance(raw_instances, dict):
        instances.update(raw_instances)
    return instances


def write_tfvars_file(payload: EC2CreateRequest) -> Path:
    terraform_dir = Path(settings.terraform_dir)
    tfvars_path = terraform_dir / settings.terraform_var_file


    instances = read_existing_instances(tfvars_path)

    if payload.instance_name in instances:
        raise ValueError(
            f"Instance '{payload.instance_name}' existe déjà."
        )

    instances[payload.instance_name] = build_instance_payload(payload)

    tfvars_data = {
        "instance_name": payload.instance_name,
        "instances": instances,
        "target_vpc_name": settings.target_vpc_name,
        "apache_private_ip": settings.apache_private_ip,
        "apache_sg_name": settings.apache_sg_name,
        "apache_instance_id": settings.apache_instance_id,
        "vpc_cidr": settings.vpc_cidr,
    }

    tfvars_path.write_text(
        json.dumps(tfvars_data, indent=2),
        encoding="utf-8",
    )
    return tfvars_path


def run_command(cmd: list, cwd: str, env: dict) -> tuple[str, str, int]:
    result = subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    return result.stdout, result.stderr, result.returncode


def run_terraform_apply(payload: EC2CreateRequest) -> dict:
    if not terraform_lock.acquire(timeout=300):
        return {
            "status": "error",
            "message": "Une autre instance est en cours de création. Réessayez dans quelques minutes.",
            "instance_name": payload.instance_name,
            "terraform_enabled": settings.terraform_enabled,
            "stdout": None,
            "stderr": None,
        }

    try:
        try:
            tfvars_path = write_tfvars_file(payload)
        except ValueError as error:
            return {
                "status": "error",
                "message": str(error),
                "instance_name": payload.instance_name,
                "terraform_enabled": settings.terraform_enabled,
                "stdout": None,
                "stderr": None,
            }

        if not settings.terraform_enabled:
            return {
                "status": "success",
                "message": "Fichier tfvars généré. Terraform non exécuté car TERRAFORM_ENABLED=false.",
                "instance_name": payload.instance_name,
                "terraform_enabled": False,
                "stdout": f"Var file généré: {tfvars_path}",
                "stderr": None,
            }

        terraform_dir = settings.terraform_dir
        env = os.environ.copy()
        env["AWS_PROFILE"] = "sopra-sso"

        stdout_all = ""
        stderr_all = ""


        stdout_all += "\n=== Étape 1 : Vérification bucket S3 ===\n"
        bucket_name = "sopra-hra4you-tfstate"
        region = "eu-west-3"

        stdout, stderr, code = run_command(
            ["aws", "s3api", "head-bucket", "--bucket", bucket_name],
            cwd=terraform_dir, env=env
        )
        if code != 0:
            stdout_all += "Bucket n'existe pas → Création...\n"
            run_command(
                ["aws", "s3api", "create-bucket",
                 "--bucket", bucket_name,
                 "--region", region,
                 "--create-bucket-configuration", f"LocationConstraint={region}"],
                cwd=terraform_dir, env=env
            )
            run_command(
                ["aws", "s3api", "put-bucket-versioning",
                 "--bucket", bucket_name,
                 "--versioning-configuration", "Status=Enabled"],
                cwd=terraform_dir, env=env
            )
            stdout_all += "Bucket créé ✅\n"
        else:
            stdout_all += "Bucket existe déjà ✅\n"


        stdout_all += "\n=== Étape 2 : Configuration backend ===\n"
        backend_content = f'''terraform {{
  backend "s3" {{
    bucket       = "{bucket_name}"
    key          = "sopra-hra4you/terraform.tfstate"
    region       = "{region}"
    encrypt      = true
    use_lockfile = true
    profile      = "sopra-sso"
  }}
}}'''
        backend_path = Path(terraform_dir) / "backend.tf"
        backend_path.write_text(backend_content, encoding="utf-8")
        stdout_all += "backend.tf configuré ✅\n"


        stdout_all += "\n=== Étape 3 : Terraform init ===\n"
        stdout, stderr, code = run_command(
            ["terraform", "init"],
            cwd=terraform_dir, env=env
        )
        stdout_all += stdout
        stderr_all += stderr
        if code != 0:
            return {"status": "error", "message": "Échec terraform init",
                    "instance_name": payload.instance_name,
                    "terraform_enabled": True,
                    "stdout": stdout_all, "stderr": stderr_all}
        stdout_all += "Terraform initialisé ✅\n"


        stdout_all += "\n=== Étape 4 : Terraform validate ===\n"
        stdout, stderr, code = run_command(
            ["terraform", "validate"],
            cwd=terraform_dir, env=env
        )
        stdout_all += stdout
        stderr_all += stderr
        if code != 0:
            return {"status": "error", "message": "Échec terraform validate",
                    "instance_name": payload.instance_name,
                    "terraform_enabled": True,
                    "stdout": stdout_all, "stderr": stderr_all}
        stdout_all += "Validation réussie ✅\n"


        stdout_all += "\n=== Étape 5 : Terraform plan ===\n"
        stdout, stderr, code = run_command(
            [
                "terraform", "plan",
                f"-var-file={settings.terraform_var_file}",
                "-out=tfplan"
            ],
            cwd=terraform_dir, env=env
        )
        stdout_all += stdout
        stderr_all += stderr
        if code != 0:
            return {"status": "error", "message": "Échec terraform plan",
                    "instance_name": payload.instance_name,
                    "terraform_enabled": True,
                    "stdout": stdout_all, "stderr": stderr_all}
        stdout_all += "Plan réussi ✅\n"


        stdout_all += "\n=== Étape 6 : Terraform apply ===\n"
        stdout, stderr, code = run_command(
            ["terraform", "apply", "-auto-approve", "tfplan"],
            cwd=terraform_dir, env=env
        )
        stdout_all += stdout
        stderr_all += stderr
        if code != 0:
            return {"status": "error", "message": "Échec terraform apply",
                    "instance_name": payload.instance_name,
                    "terraform_enabled": True,
                    "stdout": stdout_all, "stderr": stderr_all}

        stdout_all += "\n✅ Déploiement terminé avec succès !\n"

        return {
            "status": "success",
            "message": "Instance créée avec succès",
            "instance_name": payload.instance_name,
            "terraform_enabled": True,
            "stdout": stdout_all,
            "stderr": stderr_all,
        }

    finally:
        terraform_lock.release()


def get_instance_ssh_port(instance_name: str) -> dict:
    session_kwargs: dict = {}
    if settings.aws_profile:
        session_kwargs["profile_name"] = settings.aws_profile

    session = boto3.Session(**session_kwargs)
    dynamodb = session.resource("dynamodb", region_name=settings.aws_region)
    table = dynamodb.Table(settings.ssh_port_counter_table)

    item = table.get_item(Key={"counter_id": f"instance#{instance_name}"}).get("Item")
    if not item or "port" not in item:
        raise ValueError(f"Aucun port SSH trouvé pour l'instance '{instance_name}'.")

    ssh_port = int(item["port"])
    return {
        "instance_name": instance_name,
        "ssh_port": ssh_port,
        "ssh_command": f"ssh -p {ssh_port} ec2-user@{settings.apache_private_ip}",
    }