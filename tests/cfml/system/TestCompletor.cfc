component name="TestShell" extends="mxunit.framework.TestCase" {

	candidates = createObject("java","java.util.TreeSet");

	public void function setUp()  {
		completor = application.wirebox.getInstance( 'completor' );
	}

	public void function testPartialNoPrefixCommands()  {		
		cmdline = "";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.size() > 4);
		assertTrue(candidates.contains("help "));
		assertTrue(candidates.contains("dir "));
		assertTrue(candidates.contains("ls "));
		assertTrue(candidates.contains("reload "));
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
		assertTrue(candidates.contains(" command="));
		assertFalse(candidates.contains("help"));
		assertEquals(4,cursor);
		candidates.clear();

		cmdline = "help com";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains(" command="));
		assertFalse(candidates.contains("help"));
		assertEquals(4,cursor);
		candidates.clear();

		cmdline = "dir ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains(" directory="));
		assertTrue(candidates.contains(" recurse="));
		assertEquals(3,cursor);
		candidates.clear();

		cmdline = "dir directory=blah ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertFalse(candidates.contains("directory"));
		assertFalse(candidates.contains("directory="));
		assertTrue(candidates.contains(" recurse="));
		assertEquals(18,cursor);
		candidates.clear();

		cmdline = "dir directory=blah recurse=";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("true "));
		assertTrue(candidates.contains("false "));
		assertEquals(27,cursor);
		candidates.clear();

		cmdline = "dir directory=blah recurse=tr";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		debug(candidates);
		assertTrue(candidates.contains("true "));
		assertFalse(candidates.contains("false "));
		assertEquals(27,cursor);
		candidates.clear();

		cmdline = "init";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		debug(candidates);
		assertTrue(candidates.contains("init "));
		assertEquals(0,cursor);
		candidates.clear();

		cmdline = "iDoNotExist ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		debug(candidates);
		assertEquals(0,candidates.size());
		assertEquals(len(cmdline),cursor);
		candidates.clear();
	}
}