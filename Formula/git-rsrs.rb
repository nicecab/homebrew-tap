class GitRsrs < Formula
  desc "Synchronize Git repositories with external command hooks"
  homepage "https://github.com/nicecab/git-rsrs"
  version "0.1.3"

  depends_on "git"

  on_macos do
    on_arm do
      url "https://github.com/nicecab/git-rsrs/releases/download/v0.1.3/git-rsrs-v0.1.3-aarch64-apple-darwin.tar.gz"
      sha256 "b866d6d5c58b670263ac7efa7b752dcb19c551026b4a99a88ec3ae3104eed596"
    end
    on_intel do
      url "https://github.com/nicecab/git-rsrs/releases/download/v0.1.3/git-rsrs-v0.1.3-x86_64-apple-darwin.tar.gz"
      sha256 "9ade7bc6d357543ea1deee0f29e84244986cad3d326c389258df30bfbe5aecb7"
    end
  end

  on_linux do
    depends_on arch: :x86_64
    on_intel do
      url "https://github.com/nicecab/git-rsrs/releases/download/v0.1.3/git-rsrs-v0.1.3-x86_64-unknown-linux-musl.tar.gz"
      sha256 "afa3885e2370f8fc6703e90afb44fb8b84fde5be4bd1a9c37c91b11dddac291d"
    end
  end

  def install
    bin.install "git-rsrs"
    pkgshare.install "examples" if (buildpath/"examples").exist?
  end

  test do
    assert_match "git-rsrs 0.1.3", shell_output("#{bin}/git-rsrs --version")
    origin = testpath/"origin.git"
    checkout = testpath/"checkout"
    system "git", "init", "--bare", origin
    system "git", "init", "-b", "main", checkout
    system "git", "-C", checkout, "config", "user.name", "Homebrew Test"
    system "git", "-C", checkout, "config", "user.email", "test@example.invalid"
    system "git", "-C", checkout, "config", "core.hooksPath", File::NULL
    system "git", "-C", checkout, "remote", "add", "origin", origin
    (checkout/"message.txt").write "initial\n"
    system "git", "-C", checkout, "add", "-A"
    system "git", "-C", checkout, "-c", "commit.gpgsign=false", "commit", "-m", "initial"
    system "git", "-C", checkout, "push", "-u", "origin", "main"
    (testpath/"config.toml").write "version = 1\nbranch = 'main'\n"
    (checkout/"message.txt").write "updated\n", 0
    system bin/"git-rsrs", "--repo", checkout, "--config", testpath/"config.toml", "sync"
    assert_equal "updated\n", shell_output("git --git-dir=#{origin} show main:message.txt")
  end
end
