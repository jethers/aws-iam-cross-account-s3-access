# Requirements Sync Rule

Whenever a change is made to any Terraform file (`*.tf`) or project configuration in this workspace, check if the change introduces new behavior, modifies existing behavior, or removes functionality.

If it does, update the requirements document at `.kiro/specs/aws-cross-account-ec2-s3/requirements.md` to reflect the new state of the project:

- Add a new requirement if new functionality was introduced
- Update existing acceptance criteria if behavior was modified
- Remove or mark as obsolete any criteria that no longer apply
- Keep the glossary up to date with any new terms or resources

The requirements document must always reflect the current final state of the project, not the initial spec.
