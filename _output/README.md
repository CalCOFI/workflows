# workflows

This directory is the published Jekyll site at <https://calcofi.io/workflows/> —
rendered Quarto/R notebooks plus the landing page (`index.html`, driven by
`_data/workflows.yml`).

- Landing page source: `index.html` + `_layouts/default.html` + `style.css`
- Manifest generator: [`scripts/build_workflows_index.R`](https://github.com/CalCOFI/workflows/blob/main/scripts/build_workflows_index.R)
- Notebook sources: <https://github.com/CalCOFI/workflows>

This file is excluded from the build (see `_config.yml`); `index.html` is the served root.
