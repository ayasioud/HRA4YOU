$instanceName = $env:TF_INSTANCE_NAME
if ([string]::IsNullOrWhiteSpace($instanceName)) {
	throw "TF_INSTANCE_NAME est vide."
}

$targetArg = 'aws_instance.from_my_ami["' + $instanceName + '"]'
terraform plan -var-file="app.auto.tfvars.json" -target="$targetArg" -out="tfplan"
