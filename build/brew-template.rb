require "formula"
# Version update PR to Homebrew requires only the information below:
class Commandbox@be@ < Formula
  desc "A CLI, package manager, app scaffolding tool with embedded CFML server"
  homepage "http://www.ortussolutions.com/products/commandbox"
  url "@repoURL@/ortussolutions/commandbox/@version@/commandbox-bin-@version@.zip"
  sha256 "@sha256@"
  
  depends_on :arch => :x86_64
  depends_on :java => "1.7+"

  resource 'apidocs' do
    url "@repoURL@/ortussolutions/commandbox/@version@/commandbox-apidocs-@version@.zip"
    sha256 "@apidocs.sha256@"
  end

  def install
    bin.install 'box'
    doc.install resource( "apidocs" )
  end

  test do
    box install
    box server start
  end

  def caveats
    "You will need at least Java JDK 1.7+ to run CommandBox"
  end


end