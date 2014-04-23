component name="TestShell" extends="mxunit.framework.TestCase" {

	public void function setUp()  {
		shell = new cfml.box.Shell();
		variables.cfdistro = new cfml.box.namespace.cfdistro.cfdistro(shell);
	}

	public void function testInstall()  {
		cfdistro.install();
	}

	public void function testDependency()  {
		var result = cfdistro.dependency(groupId="org.mxunit",artifactId="core",version="2.1.3",mapping="/mxunit");
		//request.debug(result);
		assertTrue(fileExists(shell.getHomeDir() & "/artifacts/org/mxunit/core/"));
	}


}