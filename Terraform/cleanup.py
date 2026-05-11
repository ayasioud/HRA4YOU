import subprocess

terraform_dir = r'C:\Users\asioud\Desktop\hra4you\terraform'

imports = [
    ('aws_route53_record.instance["InfraCore"]', 'Z1014741TN82Q9A0L4BN_infracore.cloud.soprahr.com_A'),
    ('aws_ssm_parameter.ec2_user_password["InfraCore"]', '/hra4you/ssh/ec2-user-password/InfraCore'),
]

for addr, resource_id in imports:
    result = subprocess.run(
        ['terraform', 'import', addr, resource_id],
        cwd=terraform_dir,
        capture_output=True,
        text=True
    )
    if 'Import successful' in result.stdout:
        print(f'✅ {addr}')
    else:
        print(f'❌ {addr}: {result.stderr[-200:]}')