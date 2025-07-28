variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "memcached_node_type" {
  description = "ElastiCache node type for memcached cluster"
  type        = string
  default     = "cache.r6g.large"
}

variable "memcached_num_nodes" {
  description = "Number of nodes in the memcached cluster"
  type        = number
  default     = 1
}

variable "client_instance_type" {
  description = "EC2 instance type for CMBT client"
  type        = string
  default     = "r6i.xlarge"
}


variable "vpc_id" {
  description = "ID of existing VPC"
  type        = string
  default     = "vpc-7aa9121f"
}

variable "private_subnet_ids" {
  description = "List of existing private subnet IDs for ElastiCache"
  type        = list(string)
  default     = ["subnet-03aabd4ff9221d286", "subnet-0306b119642c9763f"]
}

variable "public_subnet_id" {
  description = "ID of existing public subnet for EC2 instance"
  type        = string
  default     = "subnet-6cdc7635"
}

variable "client_security_group_ids" {
  description = "List of existing security group IDs for EC2 client instance"
  type        = list(string)
  default     = ["sg-7968761d", "sg-8db8eae8"]
}

variable "key_name" {
  description = "Name of existing EC2 key pair"
  type        = string
  default     = "si-eval-cfn"
}

variable "redis_node_type" {
  description = "ElastiCache node type for Redis cluster"
  type        = string
  default     = "cache.r6g.large"
}

variable "redis_num_nodes" {
  description = "Number of nodes in the Redis cluster (for cluster mode)"
  type        = number
  default     = 1
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_parameter_group_family" {
  description = "Redis parameter group family"
  type        = string
  default     = "redis7"
}

variable "flarei_instance_type" {
  description = "EC2 instance type for Flare index server"
  type        = string
  default     = "t3.medium"
}

variable "flared_instance_type" {
  description = "EC2 instance type for Flare data servers"
  type        = string
  default     = "t3.medium"
}
