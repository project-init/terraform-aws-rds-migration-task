########################################################################################################################
### Common
########################################################################################################################

variable "service_name" {
  type        = string
  description = "The name of the service."
}

variable "environment" {
  type        = string
  nullable    = false
  description = "The name of the environment the migration is happening."
}

########################################################################################################################
### IAM
########################################################################################################################

variable "rds_user_policy_arn" {
  type        = string
  nullable    = false
  description = "The ARN of the rds user policy that can run migrations."
}

########################################################################################################################
### ECS
########################################################################################################################

variable "use_ec2" {
  type        = bool
  default     = false
  description = "Whether to deploy the service on an ec2 backed service or fargate."
}

variable "image" {
  type        = string
  nullable    = false
  description = "The docker image to use for the container."
}

variable "rds" {
  type = object({
    endpoint = string
    database = string
    username = string
  })
}

variable "subnet_id" {
  type        = string
  nullable    = false
  description = "The subnet to run the task in."
}

variable "security_group_id" {
  type        = string
  nullable    = false
  description = "The id of the security group to use for the task."
}

variable "repository_credentials_arn" {
  type        = string
  default     = null
  description = "ARN of Secrets Manager secret containing private registry credentials."
}

variable "enable_repository_credentials" {
  type        = bool
  default     = false
  description = "Whether or not to create IAM permissions for private registry image pull."
}