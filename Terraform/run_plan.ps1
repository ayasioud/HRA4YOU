terraform plan -var-file="app.auto.tfvars.json" -target='aws_instance.from_my_ami["test"]' -out="tfplan"
terraform apply -auto-approve "tfplan"
