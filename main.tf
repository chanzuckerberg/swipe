provider "git" {
}

data "git_repository" "self" {
  path = path.module
}

output "sha" {
  value       = data.git_repository.self.commit_sha
}

