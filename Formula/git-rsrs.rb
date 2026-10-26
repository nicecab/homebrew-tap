class GitRsrs < Formula
  desc "Synchronize Git repositories with external command hooks"
  homepage "https://github.com/nicecab/git-rsrs"
  version "0.1.1"

  depends_on "git"

  on_macos do
    on_arm do
      url "https://github.com/nicecab/git-rsrs/releases/download/v0.1.1/git-rsrs-v0.1.1-aarch64-apple-darwin.tar.gz"
      sha256 "c699a6f754dccb4b32e4ef336f612c5c47cd901dfc742b3e35faf39f82b1901e"
    end
    on_intel do
      url "https://github.com/nicecab/git-rsrs/releases/download/v0.1.1/git-rsrs-v0.1.1-x86_64-apple-darwin.tar.gz"
      sha256 "96e3814687926177286ee936bdb092491dbabd4d8189e2e1010902640a9f0f7f"
    end
  end

  on_linux do
    depends_on arch: :x86_64
    on_intel do
      url "https://github.com/nicecab/git-rsrs/releases/download/v0.1.1/git-rsrs-v0.1.1-x86_64-unknown-linux-musl.tar.gz"
      sha256 "f1130db23dddd6ebf38526373c28d507a9ab3c489da6e1c83d0f0a0107c302ef"
    end
  end

  def install
    bin.install "git-rsrs"
    pkgshare.install "examples" if (buildpath/"examples").exist?
  end

  test do
    assert_match "git-rsrs 0.1.1", shell_output("#{bin}/git-rsrs --version")
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
