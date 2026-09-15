# Releasing Mayu

Mayu publishes `mayu-live` and `mayu-build` from
`.github/workflows/release.yml`. A release is built from a version tag and uses
RubyGems.org Trusted Publishing, so no long-lived API key is stored in GitHub.

## One-time setup

Create a GitHub environment named `release`. It can require approval and
should restrict deployments to version tags.

On RubyGems.org, configure `release.yml` in `mayu-live/framework` as a trusted
publisher for each gem, with `release` as the environment name:

- `mayu-live`, on the gem's existing trusted publishers page
- `mayu-build`, as a pending trusted publisher until its first release

## Creating a release

Both gems share one version, `Mayu::VERSION` in
`gems/mayu-live/lib/mayu/version.rb`. `mayu-build` depends on `mayu-live` at
exactly that version.

1. Bump the version constant and refresh the lockfiles that pin it:

   ```sh
   bundle lock
   (cd example && bundle lock)
   ```

2. Commit, open a pull request, and merge it into `main`.

3. Tag the merged commit. The tag name must be `v` followed by the version:

   ```sh
   git switch main
   git pull --ff-only
   git tag -a v0.1.0 -m "Release 0.1.0"
   git push origin v0.1.0
   ```

The workflow checks that the tag matches the version and is contained in
`main`, builds the browser runtime, runs the test suite, packages both gems,
publishes `mayu-live` and then `mayu-build`, and creates a GitHub release with
the gem files attached.

## Retrying publication

The publish job never rebuilds gems. It downloads the packages built by the
verify job and skips any gem that RubyGems.org already has at that version.
If publishing fails, fix the trusted publisher or environment configuration
and use **Re-run failed jobs** on the same workflow run.
