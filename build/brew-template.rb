require "formula"
# Version update PR to Homebrew requires only the information below:
class Commandbox < Formula
  desc "CFML embedded server, package manager, and app scaffolding tools"
  homepage "http://www.ortussolutions.com/products/commandbox"
  url "@repoURL@/ortussolutions/commandbox/@version@/commandbox-bin-@stable.version@.zip"
  sha256 "@stable.sha256@"
  devel do
    url "http://integration.stg.ortussolutions.com/artifacts/ortussolutions/commandbox/@version@/commandbox-bin-@version@.zip"
    sha256 "@sha256@"
  end

  depends_on :java => "1.7+"

  resource "apidocs" do
    url "@repoURL@/ortussolutions/commandbox/@version@/commandbox-apidocs-@version@.zip"
    sha256 "@apidocs.sha256@"
  end

  def install
    bin.install "box"
    doc.install resource("apidocs")
  end

  def caveats; <<-EOS.undent
    CommandBox is licensed as open source software under the GNU Lesser General Public License v3

    License information at:
    http://www.gnu.org/licenses/lgpl-3.0.en.html

    For full CommandBox documentation visit:
    https://ortus.gitbooks.io/commandbox-documentation/

    Source Code:
    https://github.com/Ortus-Solutions/commandbox
    EOS
  end

  test do
    system "box", "--commandbox_home=~/", "version"
    system "box", "--commandbox_home=~/", "help"
  end
end
