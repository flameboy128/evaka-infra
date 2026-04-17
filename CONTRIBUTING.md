# Contributing to evaka-infra

Thank you for your interest in contributing to this project! This document explains how to contribute and what to expect from the process.

## License

By contributing to this project, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).

## How to Contribute

### Reporting Issues

If you find a bug or have a suggestion, please open a GitHub issue. Include the following where applicable:

- A clear description of the problem or suggestion
- Steps to reproduce the issue
- Relevant Terraform/Terragrunt version information
- Any error messages or plan output (with sensitive values redacted)

### Submitting Changes

1. Fork the repository and create a feature branch from `main`.
2. Make your changes. Keep commits focused — one logical change per commit.
3. Test your changes by running `terragrunt plan` on affected stacks.
4. Open a pull request against `main` with a clear description of what the change does and why.

### What We Look For in Pull Requests

- **Terraform style**: Follow [HashiCorp's Terraform style conventions](https://developer.hashicorp.com/terraform/language/style). Use `terraform fmt` to format code.
- **Variable naming**: Use the existing `name_prefix` pattern for resource names and keep variable names consistent across stacks.
- **No secrets**: Never commit real AWS account IDs, credentials, IP addresses, domain names, or other sensitive values. Use placeholders in templates.
- **Documentation**: Update the README if your change adds, removes, or modifies stacks, variables, or deployment steps. Update cost-pricing.md if your change affects infrastructure costs.

## Security

If you discover a security vulnerability, please do **not** open a public issue. Instead, contact the maintainers privately at the email address listed in the repository. <!-- TODO before publishing: Add a contact email address or create a SECURITY.md file. Currently no email is listed in the repository. -->

## Code of Conduct

Be respectful and constructive in all interactions. We are committed to providing a welcoming and inclusive experience for everyone.
<!-- TODO before publishing: Either add a CODE_OF_CONDUCT.md file (e.g., Contributor Covenant) and link to it, or expand this section. -->
