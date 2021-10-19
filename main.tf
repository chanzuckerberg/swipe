terraform {
  required_providers {
    github = {
      source  = "integrations/git"
      version = "0.1.3"
    }
  }
}

data "git_repository" "self" {
  path = path.module
}

output "sha" {
  value       = data.git_repository.self.commit_sha
}

