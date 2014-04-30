component extends="mxunit.framework.TestCase" {
//component extends="testbox.system.testing.TestBox" {

	candidates = createObject("java","java.util.TreeSet");

	public void function setUp()  {
		var shell = new cfml.cli.Shell();
		commandHandler = new cfml.cli.CommandHandler(shell);
	}

	public void function testInitCommands()  {
		commandHandler.initCommands();
		var commands = commandHandler.getCommands();
		assertTrue(structKeyExists(commands[""],"init"));

	}

	public void function testLoadCommands()  {
		commandHandler.loadCommands();
		candidates = commandHandler.getCommands();
		debug(candidates);
		assertEquals(0,candidates.size());
		assertEquals(len(cmdline),cursor);
		candidates.clear();
	}
}