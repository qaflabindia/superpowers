# Forge Commands

The skill's steps name GitHub's `gh`. Use the row for the project's forge;
the record's `Forge:` line says which. Check `<cli> --help` for the
installed version before relying on a flag — these CLIs change.

| Step | GitHub (`gh`) | GitLab (`glab`) | Azure DevOps (`az repos`, `az pipelines`) | Gitea / Forgejo (`tea`) |
|------|---------------|-----------------|------------------------------------------|-------------------------|
| PR state | `gh pr view <N> --json state,headRefOid,mergeable` | `glab mr view <N>` | `az repos pr show --id <N>` | `tea pr <N>` |
| Wait on CI | `gh pr checks <N> --required` (exit 8 pending) | `glab ci status` | `az pipelines runs list --branch <branch>`, then `az pipelines runs show --id <run>` | the forge's web UI or API |
| Merge | `gh pr merge <N> --auto --squash\|--merge\|--rebase` | `glab mr merge <N>` | `az repos pr update --id <N> --auto-complete true` | `tea pulls merge <N>` |
| Deploy run | `gh run list` / `gh run view <id>` | `glab ci list` / `glab ci view` | `az pipelines runs show --id <run>` | the forge's web UI or API |

**No CLI** (Bitbucket, a self-hosted forge without one, or a CLI that is
not installed and that your human partner doesn't want installed): read
state from the web UI through your human partner, or from the forge's REST
API with `curl` using a token they already set in the environment — never
ask them to paste one into the conversation. Merging then goes through your
human partner.

**Turning status into exit codes.** `poll-until` judges by exit code. When
a CLI exits 0 whatever the state (as `gh run view` does), wrap it in
`sh -c` and map the state to 0 (done), 1 (failed), or 8 (pending) — the
skill's Step 4 shows the pattern.
