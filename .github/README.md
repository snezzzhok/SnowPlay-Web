# GitHub automation templates

The macOS build, draft release and browser preview workflows are preserved in [`Docs/CI-Templates`](../Docs/CI-Templates). They are inactive: this repository was uploaded using a GitHub credential without the `workflow` scope.

To enable automation later, copy the desired YAML files into `.github/workflows/` and push using a credential authorized to update GitHub Actions workflows. The existing public browser scene is deployed from this repository’s main branch/root through GitHub Pages. Its root files are preserved; the optional workflow template is manual.
