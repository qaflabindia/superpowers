# Platform Signals

Part of superpowers:configuring-deploys. Each row is a hint to read further,
never a conclusion. Status commands are read-only; anything that deploys,
publishes, or rolls back is listed only so you can recognize it, and runs only
on your human partner's say-so.

## Hosting and runtime

| Signal | Likely means | Read-only status check |
|--------|--------------|------------------------|
| `fly.toml` | Fly.io app (`app = "…"`) | `fly status --app <app>` |
| `render.yaml` | Render, usually auto-deploy from a branch | poll the service URL |
| `vercel.json`, `.vercel/` | Vercel; preview per PR, production on merge | `vercel ls --prod` |
| `netlify.toml` | Netlify; deploy on push | `netlify status` |
| `Procfile`, `app.json` | Heroku-style buildpack app | `heroku releases -n 1 --app <app>` |
| `railway.json`, `railway.toml` | Railway | `railway status` |
| `app.yaml` (with `runtime:`) | Google App Engine | `gcloud app versions list` |
| `serverless.yml`, `template.yaml` (SAM), `cdk.json` | AWS serverless / CDK stack | `aws cloudformation describe-stacks --stack-name <s>` |
| `Dockerfile`, `compose.yaml` | Container build; deploy target lives elsewhere | — (find the target) |
| `k8s/`, `charts/`, `kustomization.yaml`, `skaffold.yaml` | Kubernetes | `kubectl rollout status deploy/<name> -n <ns>` |
| `*.tf`, `terragrunt.hcl` | Infrastructure as code; often not the app deploy itself | `terraform plan` only with your human partner's go — it can need credentials and lock state |
| `wrangler.toml` | Cloudflare Workers / Pages | `wrangler deployments list` |

## Pipelines

| Signal | Read it for |
|--------|-------------|
| `.github/workflows/*.yml` | `on:` triggers, `environment:` names, deploy steps; `gh run list --branch <base>` shows runs |
| `.gitlab-ci.yml` | `stages`, `rules`/`only`, `environment:`; `glab ci status` |
| `.circleci/config.yml`, `bitbucket-pipelines.yml`, `azure-pipelines.yml`, `Jenkinsfile`, `.buildkite/` | Same: trigger, environments, deploy job |
| `Makefile` / `justfile` / `package.json` scripts named `deploy`, `release`, `publish` | A manual entry point; note it, never run it to test |

## Packages and apps (a release is a publish, not a deploy)

| Signal | Publishes to | How releases usually happen |
|--------|--------------|-----------------------------|
| `package.json` without `"private": true` | npm | tag + CI publish, or `npm publish` by hand |
| `pyproject.toml` / `setup.py` | PyPI | tag + CI (trusted publishing), or `twine upload` |
| `Cargo.toml` (with `[package]` and no `publish = false`) | crates.io | `cargo publish` / cargo-release |
| `*.gemspec` | RubyGems | `gem push` / rake release |
| `go.mod` | Go module proxy | pushing a semver tag *is* the release |
| `fastlane/`, `*.xcodeproj`, `android/` | App stores | fastlane lanes; store review follows |

## Release bookkeeping

| Signal | Owns |
|--------|------|
| `.changeset/` | Version and changelog (add a changeset; do not hand-edit) |
| `release-please-config.json`, `.release-please-manifest.json` | Version and changelog from conventional commits |
| `.releaserc*`, `release.config.*` | semantic-release: version from commits, set in CI |
| `towncrier.toml` or `[tool.towncrier]` | Changelog fragments in a news directory |
| `VERSION`, a manifest `version` field | Version, kept by hand or by a script |
| `CHANGELOG.md`, `HISTORY.md`, `NEWS.md` | Changelog, kept by hand unless a tool above owns it |
