class GitRsrs < Formula
  desc "Synchronize Git repositories with external command hooks"
  homepage "https://github.com/nicecab/git-rsrs"
  head "https://github.com/nicecab/git-rsrs.git", branch: "main"

  depends_on "rust" => :build
  depends_on "git"

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match "git-rsrs", shell_output("#{bin}/git-rsrs --version")
    assert_match "Usage:", shell_output("#{bin}/git-rsrs --help")
  end
end
