locals {
  cpu    = var.use_ec2 ? 128 : 256
  memory = var.use_ec2 ? 128 : 512
}

resource "aws_iam_role" "migrator" {
  name                 = "${var.service_name}-migrator-execution-task-role"
  assume_role_policy   = data.aws_iam_policy_document.migrator_assume_role_policy.json
  permissions_boundary = var.permissions_boundary_arn
  tags = {
    Name        = "migrator-iam-role"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "migrator_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "migrator_exec_policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "ssm:StartSession",
      "ssm:DescribeSessions",
      "ssm:TerminateSession",
      "ecs:ExecuteCommand",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "migrator_exec_policy" {
  name   = "migrator-ecs-exec-policy"
  policy = data.aws_iam_policy_document.migrator_exec_policy.json
}

resource "aws_iam_role_policy_attachment" "migrator_service_policy" {
  role       = aws_iam_role.migrator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "migrator_exec_policy" {
  role       = aws_iam_role.migrator.name
  policy_arn = aws_iam_policy.migrator_exec_policy.arn
}

resource "aws_iam_role_policy_attachment" "migrator_rds_auth_policy" {
  role       = aws_iam_role.migrator.name
  policy_arn = var.rds_user_policy_arn
}

data "aws_iam_policy_document" "migrator_secrets_policy" {
  count   = var.enable_repository_credentials ? 1 : 0
  version = "2012-10-17"

  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.repository_credentials_arn]
  }
}

resource "aws_iam_policy" "migrator_secrets_policy" {
  count  = var.enable_repository_credentials ? 1 : 0
  name   = "${var.service_name}-migrator-registry-secrets"
  policy = data.aws_iam_policy_document.migrator_secrets_policy[0].json
}

resource "aws_iam_role_policy_attachment" "migrator_secrets_policy" {
  count      = var.enable_repository_credentials ? 1 : 0
  role       = aws_iam_role.migrator.name
  policy_arn = aws_iam_policy.migrator_secrets_policy[0].arn
}

resource "aws_ecs_task_definition" "migration" {
  family                   = "${var.service_name}-migration"
  network_mode             = "awsvpc"
  requires_compatibilities = [var.use_ec2 ? "EC2" : "FARGATE"]
  cpu                      = local.cpu
  memory                   = local.memory
  execution_role_arn       = aws_iam_role.migrator.arn
  task_role_arn            = aws_iam_role.migrator.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    merge(
      {
        name      = "migrator"
        image     = var.image
        essential = true

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.migration_logs.name
            "awslogs-region"        = "us-east-1"
            "awslogs-stream-prefix" = "ecs"
          }
        }

        environment = [
          {
            name  = "HOST"
            value = var.rds.endpoint
          },
          {
            name  = "PORT"
            value = "5432"
          },
          {
            name  = "DATABASE"
            value = var.rds.database
          },
          {
            name  = "USER"
            value = var.rds.username
          },
          {
            name  = "GENERATE_RDS_TOKEN"
            value = "1"
          },
          {
            name  = "SSL_MODE"
            value = "require"
          }
        ]

        cpu    = local.cpu
        memory = local.memory

        command     = ["up"]
        stopTimeout = 30

        healthCheck = {
          command = [
            "CMD-SHELL",
            "echo 'Migration container is running'"
          ]
          interval    = 10
          timeout     = 5
          retries     = 3
          startPeriod = 10
        }
      },
      var.enable_repository_credentials ? {
        repositoryCredentials = {
          credentialsParameter = var.repository_credentials_arn
        }
      } : {}
    )
  ])
}

resource "aws_cloudwatch_log_group" "migration_logs" {
  name              = "/ecs/${var.service_name}-migration"
  retention_in_days = 7

  tags = {
    Environment = var.environment
    Service     = var.service_name
    Component   = "migration"
  }
}

# SSM params for migration. The values will be read and passed to the migration task by CD.
resource "aws_ssm_parameter" "migration_subnet" {
  name        = "/${var.environment}/${var.service_name}/migration/subnet"
  type        = "String"
  value       = var.subnet_id
  description = "Subnet id to run ECS migration task"
}

resource "aws_ssm_parameter" "migration_security_group" {
  name        = "/${var.environment}/${var.service_name}/migration/security-group"
  type        = "String"
  value       = var.security_group_id
  description = "Security group id to run ECS migration task"
}
