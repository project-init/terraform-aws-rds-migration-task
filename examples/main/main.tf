module "migration" {
  source = "project-init/rds-migration-task/aws"
  # Project Init recommends pinning every module to a specific version
  # version = "vX.X.X"
}
