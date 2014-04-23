component name="TestShell" extends="mxunit.framework.TestCase" {

	public void function setUp()  {
		var shell = new cfml.box.Shell();
		variables.cfdistro = new cfml.box.namespace.cfdistro.cfdistro(shell);
	}

	public void function testInstall()  {
		cfdistro.install();
	}


}