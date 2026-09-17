output "cluster_id" {
  description = "Cluster ID."
  value       = relay_postgresql_cluster.this.id
}

output "phase" {
  description = "Cluster phase after the last apply."
  value       = relay_postgresql_cluster.this.phase
}

output "endpoint" {
  description = "Primary endpoint."
  value = {
    host = relay_postgresql_cluster.this.endpoint_host
    port = relay_postgresql_cluster.this.endpoint_port
  }
}

output "public_endpoints" {
  description = "Public endpoints by role."
  value       = relay_postgresql_cluster.this.public_endpoints
}

output "private_endpoints" {
  description = "Private endpoints by role."
  value       = relay_postgresql_cluster.this.private_endpoints
}

output "usernames" {
  description = "Created usernames."
  value       = keys(relay_postgresql_user.this)
}

output "generated_passwords" {
  description = "Generated passwords by username. Not recoverable from the API."
  value       = { for name, u in relay_postgresql_user.this : name => u.generated_password if u.generate_password }
  sensitive   = true
}
