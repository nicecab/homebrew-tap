# Nice Cabbage Homebrew tap

Homebrew formulae for Nice Cabbage command-line tools.

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

## Development

Ruby version is selected by `.ruby-version`; test dependencies are pinned in
`Gemfile.lock`.

```sh
bundle install
bundle exec ruby test/formula_test.rb
ruby -c Formula/git-rsrs.rb
```

Tap CI also loads the formula through Homebrew's DSL for the supported OS/architecture
variants and checks formula style. Actions are pinned to full commit SHAs.
