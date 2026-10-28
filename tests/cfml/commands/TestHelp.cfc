component name="TestHelp" extends="mxunit.framework.TestCase" {

	public void function testCommandService()  {
		shell = application.wirebox.getInstance( 'Shell' );
	//	helpCommand = application.wirebox.getInstance( 'commandbox.system.commands.help' );

	}

}