component name="TestHelp" extends="mxunit.framework.TestCase" {

	public void function testCommandService()  {
		shell = new commandbox.system.Shell();
		helpCommand = new commandbox.system.commands.help(shell);
		
	}

}