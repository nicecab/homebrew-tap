class GitRsrs < Formula
  desc "Synchronize Git repositories with external command hooks"
  homepage "https://github.com/nicecab/git-rsrs"
  version "0.1.2"

  depends_on "git"

  on_macos do
    on_arm do
      url "https://github.com/nicecab/git-rsrs/releases/download/v0.1.2/git-rsrs-v0.1.2-aarch64-apple-darwin.tar.gz"
      sha256 "e6c714b739997ff5c36f0b79132b1966c25e8c0c85e0d00d07bd6bf5aa1cb435"
    end
    on_intel do
      url "https://github.com/nicecab/git-rsrs/releases/download/v0.1.2/git-rsrs-v0.1.2-x86_64-apple-darwin.tar.gz"
      sha256 "4299bb86f86b42dd237a45f38b5c6d5a89f4c5c3aa9501803fe4765f9d3047ea"
    end
  end

  on_linux do
    depends_on arch: :x86_64
    on_intel do
      url "https://github.com/nicecab/git-rsrs/releases/download/v0.1.2/git-rsrs-v0.1.2-x86_64-unknown-linux-musl.tar.gz"
      sha256 "12734e262a42311cac5ea97441127cf5a4d4b0a7864be3439900460e1bc58c08"
    end
  end

  def install
    bin.install "git-rsrs"
    pkgshare.install "examples" if (buildpath/"examples").exist?
  end

  test do
    assert_match "git-rsrs 0.1.2", shell_output("#{bin}/git-rsrs --version")
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
