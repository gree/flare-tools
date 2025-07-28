terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "existing" {
  id = var.vpc_id
}

data "aws_subnet" "existing_private" {
  count = length(var.private_subnet_ids)
  id    = var.private_subnet_ids[count.index]
}

data "aws_subnet" "existing_public" {
  id = var.public_subnet_id
}

data "aws_security_group" "existing_client" {
  count = length(var.client_security_group_ids)
  id    = var.client_security_group_ids[count.index]
}

resource "aws_security_group" "elasticache" {
  name        = "cmbt-elasticache-sg"
  description = "Security group for ElastiCache memcached and Redis clusters"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    from_port       = 11211
    to_port         = 11211
    protocol        = "tcp"
    security_groups = data.aws_security_group.existing_client[*].id
    description     = "Memcached port"
  }

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = data.aws_security_group.existing_client[*].id
    description     = "Redis port"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cmbt-elasticache-sg"
  }
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "cmbt-cache-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "cmbt-cache-subnet-group"
  }
}

resource "aws_elasticache_cluster" "memcached" {
  cluster_id           = "cmbt-memcached"
  engine               = "memcached"
  node_type            = var.memcached_node_type
  num_cache_nodes      = var.memcached_num_nodes
  parameter_group_name = "default.memcached1.6"
  port                 = 11211
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.elasticache.id]

  tags = {
    Name = "cmbt-memcached-cluster"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "cmbt-redis"
  description          = "CMBT Redis cluster"
  node_type            = var.redis_node_type
  engine               = "redis"
  engine_version       = var.redis_engine_version
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.elasticache.id]

  # For single node Redis
  num_cache_clusters         = var.redis_num_nodes
  automatic_failover_enabled = var.redis_num_nodes > 1

  tags = {
    Name = "cmbt-redis-cluster"
  }
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "cmbt-redis-params"
  family = var.redis_parameter_group_family

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = {
    Name = "cmbt-redis-parameter-group"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_key_pair" "existing" {
  key_name = var.key_name
}

resource "aws_instance" "client" {
  #  ami                    = data.aws_ami.amazon_linux.id
  ami                    = "ami-03a6c5db010cede8e" # flare-memory-jammy-0.8.4
  instance_type          = var.client_instance_type
  key_name               = data.aws_key_pair.existing.key_name
  vpc_security_group_ids = data.aws_security_group.existing_client[*].id
  subnet_id              = data.aws_subnet.existing_public.id

  tags = {
    Name        = "cmbt-client"
    Environment = "production"
    Monitoring  = "off"
    Role        = "web"
  }
}

# Flare Index Server
resource "aws_instance" "flarei" {
  ami                    = "ami-03a1f7187270df398" # flarei AMI
  instance_type          = var.flarei_instance_type
  key_name               = data.aws_key_pair.existing.key_name
  vpc_security_group_ids = ["sg-7968761d", "sg-8db8eae8"]
  subnet_id              = data.aws_subnet.existing_public.id

  user_data = <<-EOF
    #!/bin/bash
    # Update server-name in existing configuration
    PRIVATE_IP=$(hostname -I | awk '{print $1}')
    sudo sed -i "s/RUN_INDEX=.*/RUN_INDEX=\"yes\"/" /etc/default/kvs-flare
    sudo sed -i "s/RUN_NODE=.*/RUN_NODE=\"no\"/" /etc/default/kvs-flare
    sudo sed -i "s/server-name = .*/server-name = $PRIVATE_IP/" /etc/flarei.conf
    
    # Download and install flare-tools debian package from S3
    cd /tmp
    aws s3 cp s3://gree-flare-dump/packages/flare-tools/flare-tools_1.0.0-1_amd64.deb ./
    sudo dpkg -i flare-tools_1.0.0-1_amd64.deb || sudo apt-get install -f -y
    
    # Restart flarei
    sudo systemctl restart kvs-flare
  EOF
  
  iam_instance_profile = aws_iam_instance_profile.flare_profile.name

  tags = {
    Name        = "flare-index-server"
    Type        = "flarei"
    Environment = "production"
    Monitoring  = "off"
    Role        = "flare-index"
  }
}

# Flare Data Server 1
resource "aws_instance" "flared1" {
  ami                    = "ami-08bff4bb6db553bb6" # flared AMI
  instance_type          = var.flared_instance_type
  key_name               = data.aws_key_pair.existing.key_name
  vpc_security_group_ids = ["sg-7968761d", "sg-8db8eae8"]
  subnet_id              = data.aws_subnet.existing_public.id

  user_data = <<-EOF
    #!/bin/bash
    # Update server-name and index-servers in existing configuration
    PRIVATE_IP=$(hostname -I | awk '{print $1}')

    sudo sed -i "s/RUN_INDEX=.*/RUN_INDEX=\"no\"/" /etc/default/kvs-flare
    sudo sed -i "s/RUN_NODE=.*/RUN_NODE=\"yes\"/" /etc/default/kvs-flare
    sudo sed -i "s/server-name = .*/server-name = $PRIVATE_IP/" /etc/flared.conf
    sudo sed -i "s/index-servers = .*/index-servers = ${aws_instance.flarei.private_ip}:13300/" /etc/flared.conf
    
    # Restart flared
    sudo systemctl restart kvs-flare
  EOF

  depends_on = [aws_instance.flarei]

  tags = {
    Name        = "flare-data-server-1"
    Type        = "flared"
    Environment = "production"
    Monitoring  = "off"
    Role        = "flare-node"
  }
}

# Flare Data Server 2
resource "aws_instance" "flared2" {
  ami                    = "ami-08bff4bb6db553bb6" # flared AMI
  instance_type          = var.flared_instance_type
  key_name               = data.aws_key_pair.existing.key_name
  vpc_security_group_ids = ["sg-7968761d", "sg-8db8eae8"]
  subnet_id              = data.aws_subnet.existing_public.id

  user_data = <<-EOF
    #!/bin/bash
    # Update server-name and index-servers in existing configuration
    PRIVATE_IP=$(hostname -I | awk '{print $1}')

    sudo sed -i "s/RUN_INDEX=.*/RUN_INDEX=\"no\"/" /etc/default/kvs-flare
    sudo sed -i "s/RUN_NODE=.*/RUN_NODE=\"yes\"/" /etc/default/kvs-flare
    sudo sed -i "s/server-name = .*/server-name = $PRIVATE_IP/" /etc/flared.conf
    sudo sed -i "s/index-servers = .*/index-servers = ${aws_instance.flarei.private_ip}:13300/" /etc/flared.conf
    
    # Restart flared
    sudo systemctl restart kvs-flare
  EOF

  depends_on = [aws_instance.flarei]

  tags = {
    Name        = "flare-data-server-2"
    Type        = "flared"
    Environment = "production"
    Monitoring  = "off"
    Role        = "flare-node"
  }
}

# IAM role for S3 access
resource "aws_iam_role" "flare_role" {
  name = "flare-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "flare-s3-access-role"
  }
}

# IAM policy for S3 access
resource "aws_iam_policy" "flare_s3_policy" {
  name = "flare-s3-access-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectAcl"
        ]
        Resource = "arn:aws:s3:::gree-flare-dump/packages/flare-tools/*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "flare_s3_policy_attachment" {
  role       = aws_iam_role.flare_role.name
  policy_arn = aws_iam_policy.flare_s3_policy.arn
}

# Instance profile
resource "aws_iam_instance_profile" "flare_profile" {
  name = "flare-instance-profile"
  role = aws_iam_role.flare_role.name
}
