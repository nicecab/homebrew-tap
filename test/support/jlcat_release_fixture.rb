require "digest"

module JlcatReleaseFixture
  def self.create(directory)
    release = { "tag_name" => "v1.2.3", "draft" => false, "prerelease" => false, "assets" => [] }
    hashes = {}
    %w[aarch64-apple-darwin x86_64-apple-darwin x86_64-unknown-linux-musl].each do |target|
      name = "jlcat-v1.2.3-#{target}.tar.gz"
      content = "archive for #{target}\n"
      hashes[target] = Digest::SHA256.hexdigest(content)
      File.binwrite(File.join(directory, name), content)
      File.write(File.join(directory, "#{name}.sha256"), "#{hashes[target]}  #{name}\n")
      [name, "#{name}.sha256"].each do |asset|
        release["assets"] << { "name" => asset, "browser_download_url" => "https://github.com/nicecab/jlcat/releases/download/v1.2.3/#{asset}" }
      end
    end
    [release, hashes]
  end
end
