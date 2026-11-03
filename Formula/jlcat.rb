class Jlcat < Formula
  desc "JSON/JSONL table viewer with auto-flattening and TUI support"
  homepage "https://github.com/nicecab/jlcat"
  version "0.2.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/nicecab/jlcat/releases/download/v0.2.0/jlcat-v0.2.0-aarch64-apple-darwin.tar.gz"
      sha256 "d1d188403b219a3ea7778872a3e07f74df0137a246526c9a61a97d7bbfbec704"
    end
    on_intel do
      url "https://github.com/nicecab/jlcat/releases/download/v0.2.0/jlcat-v0.2.0-x86_64-apple-darwin.tar.gz"
      sha256 "e8ce73e1493b864d1e5dd330101b5bd34a63a0dc4c838cf9556fc2ca1ca70780"
    end
  end

  on_linux do
    depends_on arch: :x86_64
    on_intel do
      url "https://github.com/nicecab/jlcat/releases/download/v0.2.0/jlcat-v0.2.0-x86_64-unknown-linux-musl.tar.gz"
      sha256 "f79b3b9d59d10c03a65cb27a0f33fe2e3acb6675074b613300cc2b9ab4cbf3fc"
    end
  end

  def install
    bin.install "jlcat"
  end

  test do
    assert_match "jlcat 0.2.0", shell_output("#{bin}/jlcat --version")
    assert_match "Alice", pipe_output("#{bin}/jlcat", "{\"name\":\"Alice\"}\n", 0)
  end
end
