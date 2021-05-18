class Commandbox < Formula
  desc "CFML embedded server, package manager, and app scaffolding tools"
  homepage "https://www.ortussolutions.com/products/commandbox"
  url "@repoPRDURL@/ortussolutions/commandbox/@stable-version@/commandbox-bin-@stable-version@.zip"
  sha256 "@stable-sha256@"
  license "LGPL-3.0-or-later"

  head do
    url "@repoURL@/ortussolutions/commandbox/@version@/commandbox-bin-@version@.zip?build=@buildnumber@"
    sha256 "@sha256@"
  end

  livecheck do
    url :homepage
    regex(/Download CommandBox v?(\d+(?:\.\d+)+)/i)
  end

  bottle do
    sha256 cellar: :any_skip_relocation, all: "45b01d0263bf8842d6b060ed23202a77ab6b33d2a3c1c2a89be80eb4c50324ba"
  end

  depends_on "openjdk"

  resource "apidocs" do
    url "@repoPRDURL@/ortussolutions/commandbox/@stable-version@/commandbox-apidocs-@stable-version@.zip"
    sha256 "@apidocs.stable-sha256@"
  end

  def install
    (libexec/"bin").install "box"
    (bin/"box").write_env_script libexec/"bin/box", Language::Java.overridable_java_home_env
    doc.install resource("apidocs")
  end

  test do
    system "#{bin}/box", "--commandbox_home=~/", "version"
    system "#{bin}/box", "--commandbox_home=~/", "help"
  end
end
