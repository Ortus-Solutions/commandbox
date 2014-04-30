component name="TestHelp" extends="mxunit.framework.TestCase" {

	public void function testCommandHandler()  {
		shell = new cfml.cli.Shell();
		helpCommand = new cfml.cli.commands.help(shell);
		
		
	//	writeDump( helpCommand.run() );abort;

	}

}