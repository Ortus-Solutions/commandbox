class Commandbox < Formula
  desc "CFML embedded server, package manager, and app scaffolding tools"
  homepage "https://www.ortussolutions.com/products/commandbox"
  url "@repoPRDURL@/ortussolutions/commandbox/@stable-version@/commandbox-bin-@stable-version@.zip"
  sha256 "@stable-sha256@"
  version "@stable-version@"

  devel do
    url "@repoURL@/ortussolutions/commandbox/@version@/commandbox-bin-@version@.zip"
    sha256 "@sha256@"
    version "@version@"
  end

  bottle :unneeded

  depends_on :java => "1.7+"

  resource "apidocs" do
    url "@repoPRDURL@/ortussolutions/commandbox/@stable-version@./commandbox-apidocs-@stable-version@.zip"
    sha256 "@apidocs.stable-sha256@"
  end

  def install
    bin.install "box"
    doc.install resource("apidocs")
  end

  test do
    system "box", "--commandbox_home=~/", "version"
    system "box", "--commandbox_home=~/", "help"
  end
end
