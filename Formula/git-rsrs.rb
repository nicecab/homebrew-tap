class GitRsrs < Formula
  desc "Synchronize Git repositories with external command hooks"
  homepage "https://github.com/nicecab/git-rsrs"
  version "0.1.0"

  depends_on "git"

  on_macos do
    on_arm do
      url "https://github.com/nicecab/git-rsrs/releases/download/v0.1.0/git-rsrs-v0.1.0-aarch64-apple-darwin.tar.gz"
      sha256 "baad229ea59e08f8902b4d79f9309ac5cdd61026eeb7a41c7137858bc42af845"
    end
    on_intel do
      url "https://github.com/nicecab/git-rsrs/releases/download/v0.1.0/git-rsrs-v0.1.0-x86_64-apple-darwin.tar.gz"
      sha256 "c5e4d0aa5b2e114c466301168086a74c04344e31cf5818c1cf4afc89e0ad4ab0"
    end
  end

  on_linux do
    depends_on arch: :x86_64
    on_intel do
      url "https://github.com/nicecab/git-rsrs/releases/download/v0.1.0/git-rsrs-v0.1.0-x86_64-unknown-linux-musl.tar.gz"
      sha256 "d8b50b01074247ac904a76fa1a95355cbb614b8f70d795a54d8f4af0076809ca"
    end
  end

  def install
    bin.install "git-rsrs"
    pkgshare.install "examples" if (buildpath/"examples").exist?
  end

  test do
    assert_match "git-rsrs 0.1.0", shell_output("#{bin}/git-rsrs --version")
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
