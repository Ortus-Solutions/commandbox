component name="TestShell" extends="mxunit.framework.TestCase" {

	candidates = createObject("java","java.util.TreeSet");

	public void function setUp()  {
		completor = application.wirebox.getInstance( 'Completor' );
		candidates.clear();
	}


	public void function testNoCommand() {
		cmdline = "";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.size() > 4);
		assertTrue(candidates.contains("help "));
		assertTrue(candidates.contains("dir "));
		assertTrue(candidates.contains("ls "));
		assertTrue(candidates.contains("reload "));
		assertEquals(0,cursor);
	}

	public void function testPartialCommand() {
		cmdline = "hel";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("help "));
		assertTrue(candidates.size() == 1);
		assertEquals(0,cursor);
	}

	public void function testCommandNoSpace() {
		cmdline = "help";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("help "));
		assertTrue(candidates.size() == 1);
		assertEquals(0,cursor);
	}

	public void function testCommandSpace() {
		cmdline = "help ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("command="));
		assertFalse(candidates.contains("help"));
		assertEquals(5,cursor);
	}

	public void function testCommandSpaceMultipleParams() {
		cmdline = "dir ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("directory="));
		assertTrue(candidates.contains("recurse="));
		assertEquals(4,cursor);
	}


	public void function testPartialParamName() {
		cmdline = "help com";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("command="));
		assertFalse(candidates.contains("help"));
		assertEquals(5,cursor);
	}


	public void function testPartialParamNameSecondParam() {
		cmdline = "dir directory=blah re";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains(" recurse="));
		assertEquals(18,cursor);
	}

	public void function testParamAndValue() {
		cmdline = "dir directory=blah ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertFalse(candidates.contains("directory"));
		assertFalse(candidates.contains("directory="));
		assertTrue(candidates.contains(" recurse="));
		assertEquals(18,cursor);
	}

	public void function testBooleanParam() {
		cmdline = "dir directory=blah recurse=";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("true "));
		assertTrue(candidates.contains("false "));
		assertEquals(27,cursor);
	}

	public void function testParitialBooleanParam() {
		cmdline = "dir directory=blah recurse=tr";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("true "));
		assertFalse(candidates.contains("false "));
		assertEquals(27,cursor);
	}

	public void function testFlags() {
		cmdline = "rm ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains("--force "));
		assertTrue(candidates.contains("--recurse "));
		assertEquals(3,cursor);
	}

	public void function testFlagsNotNamed() {
		cmdline = "rm recurse=true ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertTrue(candidates.contains(" --force "));
		assertFalse(candidates.contains(" --recurse "));
		assertEquals(15,cursor);
	}

	public void function testFlagsNotPositional() {
		cmdline = "rm folder true ";
		cursor = completor.complete(cmdline,len(cmdline),candidates);
		assertFalse(candidates.contains(" --force "));
		assertTrue(candidates.contains(" --recurse "));
		assertEquals(15,cursor);
	}

}