require "digest"

module CaskReleaseFixture
  def self.create(directory)
    name = "rsrsbar-v1.2.3-aarch64-apple-darwin.zip"
    content = "zip archive for rsrsbar\n"
    sha256 = Digest::SHA256.hexdigest(content)
    File.binwrite(File.join(directory, name), content)
    File.write(File.join(directory, "#{name}.sha256"), "#{sha256}  #{name}\n")
    assets = [name, "#{name}.sha256"].map do |asset|
      { "name" => asset, "browser_download_url" => "https://github.com/nicecab/rsrsbar/releases/download/v1.2.3/#{asset}" }
    end
    release = { "tag_name" => "v1.2.3", "draft" => false, "prerelease" => false, "assets" => assets }
    [release, sha256]
  end
end
