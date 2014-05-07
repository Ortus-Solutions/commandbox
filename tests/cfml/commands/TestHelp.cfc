component name="TestHelp" extends="mxunit.framework.TestCase" {

	public void function testCommandHandler()  {
		shell = new commandbox.system.Shell();
		helpCommand = new commandbox.commands.help(shell);
		
		
	//	writeDump( helpCommand.run() );abort;

	}

}