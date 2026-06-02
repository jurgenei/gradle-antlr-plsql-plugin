# Release Notes (Next Tag)

Date: 2026-05-29
Scope: `antlr-grammars-plsql` release notes sync for `0.1.1`

## Highlights

- Version line remains on `0.1.1` for the release branch.
- Grammar artifact packaging and jar layout verification remain enabled.
- Local parser experimentation tasks remain available for PL/SQL scenarios.

## Notes

- This release-note update is a repository-level sync entry for the release branch.
- No additional release-note-only behavioral deltas are introduced in this file.

## Quality Automation

- Added baseline `qodana.yaml` for JVM community linting on JDK 21.
- Added `.github/workflows/qodana_code_quality.yml` with triggers aligned to existing CI events.
- Qodana workflow uses read-only permissions and publishes scan results without auto-fixes.

