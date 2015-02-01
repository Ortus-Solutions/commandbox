require "formula"

class Commandbox < Formula
  homepage "http://www.ortussolutions.com/products/commandbox"
  url "http://integration.stg.ortussolutions.com/artifacts/ortussolutions/commandbox/1.0.0/commandbox-bin-1.0.0.zip"
  sha1 ""
  version "1.0.0"
  
  depends_on :arch => :x86_64

  resource 'apidocs' do
    url "http://integration.stg.ortussolutions.com/artifacts/ortussolutions/commandbox/1.0.0/commandbox-apidocs-1.0.0.zip"
    sha1 ""
  end

  def install
    bin.install 'box'
    doc.install resource( "apidocs" )
  end

  def caveats
    "You will need at least Java JDK 1.7+ to run CommandBox"
  end


end
