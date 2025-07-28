# CMBT Infrastructure with Terraform

This Terraform configuration sets up AWS ElastiCache (Memcached and Redis) infrastructure for benchmarking with CMBT.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed (>= 1.0)
- Existing AWS infrastructure:
  - VPC ID
  - Private subnet IDs (at least 2 for ElastiCache subnet group)
  - Public subnet ID (for EC2 client instance)
  - Security group ID (for EC2 client instance)

## Usage

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values:
   - Replace placeholder IDs with your existing infrastructure IDs
   - Add your SSH public key for EC2 access
   - Adjust instance types if needed

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Review the plan:
   ```bash
   terraform plan
   ```

5. Apply the configuration:
   ```bash
   terraform apply
   ```

## Resources Created

- **ElastiCache Memcached Cluster**: Single node cache.r6g.large instance
- **ElastiCache Redis Replication Group**: Single node cache.r6g.large instance (Redis 7.0)
- **ElastiCache Security Group**: Allows memcached port (11211) and Redis port (6379) from client security group
- **ElastiCache Subnet Group**: Uses your existing private subnets
- **ElastiCache Redis Parameter Group**: Custom parameters for Redis cluster
- **EC2 Instance**: r6i.xlarge instance for running CMBT benchmarks
- **EC2 Key Pair**: For SSH access to the EC2 instance

## Outputs

- `memcached_cluster_address`: ElastiCache Memcached cluster endpoint
- `memcached_port`: ElastiCache Memcached cluster port (11211)
- `redis_primary_endpoint_address`: ElastiCache Redis primary endpoint
- `redis_configuration_endpoint_address`: ElastiCache Redis configuration endpoint (for cluster mode)
- `redis_port`: ElastiCache Redis port (6379)
- `redis_replication_group_id`: ElastiCache Redis replication group ID
- `client_instance_ip`: Public IP of the EC2 client instance
- `client_instance_private_ip`: Private IP of the EC2 client instance
- `elasticache_security_group_id`: Security group ID for ElastiCache clusters

## Running CMBT

After deployment, SSH into the EC2 instance and run CMBT:

```bash
ssh -i your-key.pem ec2-user@<client_instance_ip>

# Clone and build CMBT
git clone https://github.com/your-repo/mcb.git
cd mcb
cargo build --release

# Run benchmark against Memcached
./target/release/cmbt -P memcached -a <memcached_cluster_address> -p 11211 -S mixed -t 30

# Run benchmark against Redis
./target/release/cmbt -P redis -a <redis_primary_endpoint_address> -p 6379 -S mixed -t 30
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```