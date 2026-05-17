# Helm Charts

This repository contains Helm charts under `charts/` and a GitHub workflow to update a chart's `appVersion` and chart `version`.

## Workflow: Update Helm Chart

File: `.github/workflows/update-chart.yml`

### Inputs

- `chart` (required): Chart directory name below `charts/`.
- `app_version` (required): Target application tag as v-prefixed SemVer, for example `v1.2.3`.
- `chart_version` (optional): Explicit chart version. If omitted, the workflow bumps the patch version.

### What it does

1. Validates inputs (`chart`, `app_version`, optional `chart_version`).
2. Loads `name`, `version`, and `appVersion` from `charts/<chart>/Chart.yaml`.
3. Verifies `name` matches the selected chart.
4. Resolves the next chart version:
   - uses `chart_version` when provided, or
   - bumps patch of current `version`.
5. Updates `version` and `appVersion` in `Chart.yaml` using `yq`.
6. Lints the chart and opens a pull request with the change.

### No-op behavior

The workflow sets `changed=false` and skips lint/PR creation when:

- current `appVersion` already equals `app_version`, or
- both target `version` and `appVersion` are already present.

### Example workflow_dispatch run

GitHub UI:

1. Open Actions and select the Update Helm Chart workflow.
2. Click Run workflow.
3. Provide inputs like:
    - `chart`: `faker-api`
    - `app_version`: `v1.0.2`
    - `chart_version`: leave empty to auto-bump patch (or set `0.1.4` explicitly)

GitHub CLI (optional):

```bash
gh workflow run update-chart.yml \
   -f chart=faker-api \
   -f app_version=v1.0.2
```

With explicit chart version:

```bash
gh workflow run update-chart.yml \
   -f chart=faker-api \
   -f app_version=v1.0.2 \
   -f chart_version=0.1.4
```

### Notes

- `app_version` must match: `vMAJOR.MINOR.PATCH` with optional prerelease/build metadata.
- `chart_version` must match SemVer without `v` prefix.
- The prepare logic lives in `.github/scripts/prepare-chart-update.sh`.
