terraform {
  required_version = ">= 1.7"

  required_providers {
    relay = {
      source  = "relay-sh/relay"
      version = "~> 0.1"
    }
  }
}
