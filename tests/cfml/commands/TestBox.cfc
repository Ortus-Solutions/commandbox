component name="TestShell" extends="mxunit.framework.TestCase" {

	workdir = expandPath("/tests/work");
	homedir = workdir & "/home";

	public void function beforeTests()  {
		shell = application.wirebox.getInstance( 'Shell' );
		directoryExists(workdir) ? directoryDelete(workdir,true) : "";
		directoryCreate(workdir);
		directoryCreate(homedir);
		shell.cd(workdir);
		shell.setHomeDir(homedir);
		variables.boxInit = application.wirebox.getInstance( 'commandbox.commands.init' );
		variables.boxUpgrade = application.wirebox.getInstance( 'commandbox.system.commands.upgrade' );
	}

	public void function testInit()  {
		assertTrue(shell.getHomeDir() == homedir);
		assertTrue(shell.getTempDir() == homedir & "/temp");
		var result = boxInit.run( force=true );
		assertTrue(fileExists(workdir & "/box.json"));
	}

	public void function testUpgrade()  {
		boxUpgrade.run();
		assertTrue(directoryExists(homedir & "/artifacts/org/coldbox"));
		assertTrue(directoryExists(homedir & "/cfml"));
	}

}