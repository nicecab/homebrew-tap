# Nice Cabbage Homebrew tap

Homebrew formulae and casks for Nice Cabbage tools.

## git-rsrs

After the first stable git-rsrs release is published and the formula updater has
run, install prebuilt macOS arm64/Intel or Linux x86_64 musl binaries with:

```sh
brew install nicecab/tap/git-rsrs
```

Until then, the HEAD formula builds the default branch from source with Rust:

```sh
brew install --HEAD nicecab/tap/git-rsrs
```

The initial git-rsrs implementation must be merged into its default branch before
the HEAD build is available. Stable formula generation uses actual published
archives and checksums, never placeholder hashes or nonexistent version tags.

## jlcat

jlcat is a JSON/JSONL table viewer with auto-flattening and TUI support. Install
prebuilt macOS arm64/Intel or Linux x86_64 musl binaries with:

```sh
brew install nicecab/tap/jlcat
```

jlcat was previously distributed from the `tomoya55/jlcat` tap, which no longer
receives updates. To switch an existing installation:

```sh
brew uninstall jlcat
brew untap tomoya55/jlcat
brew install nicecab/tap/jlcat
```

## rsrsbar

rsrsbar is the menu bar manager for git-rsrs auto-sync watchers. The cask installs
the ad-hoc-signed `rsrsbar.app` from the published GitHub release into
`/Applications` and links the `rsrsbar` command onto `PATH`. It requires macOS 15
(Sequoia) or later on Apple Silicon and installs `nicecab/tap/git-rsrs` as a
dependency.

```sh
brew install --cask nicecab/tap/rsrsbar
rsrsbar start
```

Allow notifications when the app asks; watcher failures are reported through them.

Upgrading with `brew upgrade --cask rsrsbar` stops the app, so run `rsrsbar start`
again afterwards. The cask cannot restart it: its install steps run in Homebrew's
sandbox, which refuses `launchctl bootstrap` and LaunchServices. Because the app
is ad-hoc signed, Homebrew quarantines the download; the cask's `preflight_steps`
removes the `com.apple.quarantine` attribute from the staged app so Gatekeeper
lets it run.

Before uninstalling, run `rsrsbar remove <id>` for each registered repository;
watchers left behind keep running without anyone to report their failures. Then:

```sh
brew uninstall --cask rsrsbar
```

Uninstalling unloads the `com.nicecab.rsrsbar` and `com.nicecab.rsrsbar.heartbeat`
launchd jobs. Add `--zap` to also remove the app's application support, cache and
log files.

## Updates

The `Update git-rsrs` workflow checks the public upstream release hourly. It can
also be run manually to pick up a new release sooner. Scheduled execution can be
delayed by GitHub Actions load. No cross-repository personal access token is needed:
the workflow reads public git-rsrs assets and uses this tap's own `GITHUB_TOKEN` to
commit verified formula changes.

Before changing the formula, the updater verifies all three platform archives
against their checksum files and any GitHub-provided asset digests. It rejects
missing/duplicated assets, unexpected URLs, unstable tags, downgrades and changed
checksums for an already published version. Formula replacement is atomic.
It then installs and tests the generated formula on macOS before committing it.
The formula test performs a local Git synchronization without network access.

The updater stays idle until a stable upstream release exists. It does not create
upstream tags or releases. GitHub may suspend scheduled workflows in inactive
public repositories; re-enable the workflow or run it manually when needed.

The `Update rsrsbar` workflow does the same for the cask: it checks the public
rsrsbar release hourly, downloads the single Apple Silicon archive and its checksum
file, and verifies the archive against the checksum file and any GitHub-provided
asset digest. It rejects missing or duplicated assets, additional `.zip` or
`.sha256` assets (other asset kinds are tolerated), unexpected URLs, unstable
tags, downgrades and changed checksums for an already published version. Cask
replacement is atomic.
Before committing, it installs the candidate cask on macOS and checks that
`rsrsbar --version` reports the release version.

The `Update jlcat` workflow does the same for the jlcat formula: it checks the
public jlcat release hourly, verifies the macOS arm64/Intel and Linux x86_64 musl
archives against their checksum files and any GitHub-provided asset digests, and
applies the same rejection rules as the git-rsrs updater. It installs and tests the
generated formula on macOS before committing it.

## Development

Ruby 4.0.9 is selected by `.ruby-version`; [mise](https://mise.jdx.dev/) reads
this file when installed and can install the selected version with `mise install`.
Test dependencies are pinned in `Gemfile.lock`.

```sh
bundle install
bundle exec ruby test/formula_test.rb
bundle exec ruby test/jlcat_formula_test.rb
bundle exec ruby test/cask_test.rb
ruby -c Formula/git-rsrs.rb
ruby -c Formula/jlcat.rb
ruby -c Casks/rsrsbar.rb
```

Tap CI also loads the formula through Homebrew's DSL for the supported OS/architecture
variants and checks formula style. The Actions lockfile pins workflow dependencies
to full commit SHAs.
After changing workflow actions, run `gh actions-lock` using the
[GitHub CLI extension](https://github.com/github/gh-actions-lock) and commit the
updated lockfile. CI verifies the lockfile; Renovate maintains dependencies.

For the cask, CI trusts a temporary `nicecab/ci` tap (Homebrew 7 skips untrusted
taps), loads and audits the cask there, and renders a second cask from the test
fixture.
