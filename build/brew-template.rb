require "formula"

class Commandbox < Formula
  homepage "http://www.ortussolutions.com/products/commandbox"
  url "@repoURL@/ortussolutions/commandbox/@version@/commandbox-bin-@version@.zip"
  sha1 "@sha1@"
  version "@version@"
  
  depends_on :arch => :x86_64

  resource 'apidocs' do
    url "@repoURL@/ortussolutions/commandbox/@version@/commandbox-apidocs-@version@.zip"
    sha1 "@apidocs.sha1@"
  end

  def install
    bin.install 'box'
    doc.install resource( "apidocs" )
  end

  def caveats
    "You will need at least Java JDK 1.7+ to run CommandBox"
  end


end
