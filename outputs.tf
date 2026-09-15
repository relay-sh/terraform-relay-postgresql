output "database_id" {
  description = "Database ID."
  value       = relay_database.this.id
}

output "phase" {
  description = "Cluster phase after the last apply."
  value       = relay_database.this.phase
}

output "endpoint" {
  description = "Primary endpoint."
  value = {
    host = relay_database.this.endpoint_host
    port = relay_database.this.endpoint_port
  }
}

output "public_endpoints" {
  description = "Public endpoints by role."
  value       = relay_database.this.public_endpoints
}

output "private_endpoints" {
  description = "Private endpoints by role."
  value       = relay_database.this.private_endpoints
}

output "usernames" {
  description = "Created usernames."
  value       = keys(relay_database_user.this)
}

output "generated_passwords" {
  description = "Generated passwords by username. Not recoverable from the API."
  value       = { for name, u in relay_database_user.this : name => u.generated_password if u.generate_password }
  sensitive   = true
}
