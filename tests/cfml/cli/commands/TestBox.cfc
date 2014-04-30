component name="TestShell" extends="mxunit.framework.TestCase" {

	workdir = expandPath("/tests/work");
	homedir = workdir & "/home";

	public void function beforeTests()  {
		shell = new cfml.cli.Shell();
		directoryExists(workdir) ? directoryDelete(workdir,true) : "";
		directoryCreate(workdir);
		directoryCreate(homedir);
		shell.cd(workdir);
		shell.setHomeDir(homedir);
		variables.box = new cfml.cli.commands.box(shell);
	}

	public void function testInit()  {
		assertTrue(shell.getHomeDir() == homedir);
		assertTrue(shell.getTempDir() == homedir & "/temp");
		var result = box.initializeBoxApp(force=true);
		assertTrue(fileExists(workdir & "/box.json"));
	}

	public void function testUpdate()  {
		box.update();
		assertTrue(directoryExists(homedir & "/artifacts/org/coldbox"));
		assertTrue(directoryExists(homedir & "/cfml"));
	}

}