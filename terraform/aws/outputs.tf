output "memcached_cluster_address" {
  description = "ElastiCache memcached cluster configuration endpoint"
  value       = aws_elasticache_cluster.memcached.cluster_address
}

output "memcached_port" {
  description = "ElastiCache memcached cluster port"
  value       = aws_elasticache_cluster.memcached.port
}

output "client_instance_ip" {
  description = "Public IP address of the CMBT client instance"
  value       = aws_instance.client.public_ip
}

output "client_instance_private_ip" {
  description = "Private IP address of the CMBT client instance"
  value       = aws_instance.client.private_ip
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = data.aws_vpc.existing.id
}

output "elasticache_security_group_id" {
  description = "ID of the ElastiCache security group"
  value       = aws_security_group.elasticache.id
}

output "redis_primary_endpoint_address" {
  description = "ElastiCache Redis primary endpoint address"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_configuration_endpoint_address" {
  description = "ElastiCache Redis configuration endpoint address (for cluster mode)"
  value       = aws_elasticache_replication_group.redis.configuration_endpoint_address
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_replication_group_id" {
  description = "ElastiCache Redis replication group ID"
  value       = aws_elasticache_replication_group.redis.id
}

# Flare cluster outputs
output "flarei_public_ip" {
  description = "Public IP address of the Flare index server"
  value       = aws_instance.flarei.public_ip
}

output "flarei_private_ip" {
  description = "Private IP address of the Flare index server"
  value       = aws_instance.flarei.private_ip
}

output "flared1_public_ip" {
  description = "Public IP address of Flare data server 1"
  value       = aws_instance.flared1.public_ip
}

output "flared1_private_ip" {
  description = "Private IP address of Flare data server 1"
  value       = aws_instance.flared1.private_ip
}

output "flared2_public_ip" {
  description = "Public IP address of Flare data server 2"
  value       = aws_instance.flared2.public_ip
}

output "flared2_private_ip" {
  description = "Private IP address of Flare data server 2"
  value       = aws_instance.flared2.private_ip
}

output "flare_index_endpoint" {
  description = "Flare index server endpoint"
  value       = "${aws_instance.flarei.public_ip}:13300"
}