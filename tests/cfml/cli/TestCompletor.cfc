component name="TestShell" extends="mxunit.framework.TestCase" {

	candidates = createObject("java","java.util.TreeSet");

	public void function setUp()  {
		var shell = new cfml.cli.Shell();
		var commandHandler = new cfml.cli.CommandHandler(shell);
		commandHandler.initCommands();
		variables.completor = new cfml.cli.Completor(commandHandler);
	}

	public void function testPartialNoPrefixCommands()  {
		cmdline = "";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.size() > 4);
		assertTrue(candidates.contains("help"));
		assertTrue(candidates.contains("dir"));
		assertTrue(candidates.contains("ls"));
		assertTrue(candidates.contains("cfdistro"));
		assertEquals(0,cursor);
		candidates.clear();

		cmdline = "help";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("help "));
		assertTrue(candidates.size() == 1);
		assertEquals(0,cursor);
		candidates.clear();

		cmdline = "help ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("command="));
		assertFalse(candidates.contains("help"));
		assertEquals(5,cursor);
		candidates.clear();

		cmdline = "help com";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("command="));
		assertFalse(candidates.contains("help"));
		assertEquals(5,cursor);
		candidates.clear();

		cmdline = "dir ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("directory"));
		assertTrue(candidates.contains("recurse"));
		assertEquals(4,cursor);
		candidates.clear();

		cmdline = "dir directory=blah ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertFalse(candidates.contains("directory"));
		assertFalse(candidates.contains("directory="));
		assertTrue(candidates.contains("recurse="));
		assertEquals(19,cursor);
		candidates.clear();

		cmdline = "dir directory=blah recurse=";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("true"));
		assertTrue(candidates.contains("false"));
		assertEquals(27,cursor);
		candidates.clear();

		cmdline = "dir directory=blah recurse=tr";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		debug(candidates);
		assertTrue(candidates.contains("true "));
		assertFalse(candidates.contains("false "));
		assertEquals(27,cursor);
		candidates.clear();

		cmdline = "cfdistro ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("war"));
		assertTrue(candidates.contains("dependency"));
		assertEquals(len(cmdline),cursor);
		candidates.clear();

		cmdline = "cfdistro war";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("war "));
		assertFalse(candidates.contains("dependency "));
		assertEquals(9,cursor);
		candidates.clear();

		cmdline = "cfdistro d";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("dependency "));
		assertFalse(candidates.contains("build "));
		assertEquals(9,cursor);
		candidates.clear();

		cmdline = "cfdistro dependency ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		debug(candidates);
		assertTrue(candidates.contains("artifactId"));
		assertTrue(candidates.contains("exclusions"));
		assertEquals(len(cmdline),cursor);
		candidates.clear();

		cmdline = "init";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		debug(candidates);
		assertTrue(candidates.contains("init"));
		assertEquals(len(cmdline),cursor);
		candidates.clear();

		cmdline = "iDoNotExist ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		debug(candidates);
		assertEquals(0,candidates.size());
		assertEquals(len(cmdline),cursor);
		candidates.clear();
	}
}