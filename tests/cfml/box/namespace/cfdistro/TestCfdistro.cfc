component name="TestShell" extends="mxunit.framework.TestCase" {

	workdir = expandPath("/tests/work");
	homedir = workdir & "/home";

	public void function beforeTests()  {
		shell = new cfml.box.Shell();
		directoryExists(workdir) ? directoryDelete(workdir,true) : "";
		directoryCreate(workdir);
		directoryCreate(homedir);
		shell.cd(workdir);
		shell.setHomeDir(homedir);
		variables.cfdistro = new cfml.box.namespace.cfdistro.cfdistro(shell);
	}

	public void function testInstall()  {
		cfdistro.install();
	}

	public void function testDependency()  {
		var result = cfdistro.dependency(groupId="org.mxunit",artifactId="core",version="2.1.3",mapping="/mxunit");
		//request.debug(result);
		//assertTrue(directoryExists(shell.getArtifactsDir() & "/org/mxunit/"));
	}


}