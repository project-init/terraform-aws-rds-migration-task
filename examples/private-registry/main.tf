module "migration" {
  source = "project-init/rds-migration-task/aws"
  # Project Init recommends pinning every module to a specific version
  # version = "vX.X.X"

  service_name        = "example"
  environment         = "production"
  rds_user_policy_arn = "arn:aws:iam::123456789012:policy/example-rds-migrator"
  image               = "registry.example.com/example/migrator:latest"

  rds = {
    endpoint = "example.cluster-abc123.us-east-1.rds.amazonaws.com"
    database = "example"
    username = "migrator"
  }

  subnet_id         = "subnet-0123456789abcdef0"
  security_group_id = "sg-0123456789abcdef0"

  # Attach an IAM permissions boundary to the task execution role. Required in
  # accounts that mandate a boundary on every role.
  permissions_boundary_arn = "arn:aws:iam::123456789012:policy/example-permissions-boundary"

  # Pull the migrator image from a private registry. Set
  # enable_repository_credentials to grant the execution role permission to read
  # the Secrets Manager secret holding the registry credentials, and point
  # repository_credentials_arn at that secret.
  enable_repository_credentials = true
  repository_credentials_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:example/registry-credentials"
}
