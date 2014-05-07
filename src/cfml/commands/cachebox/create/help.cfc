component extends="commandbox.system.BaseCommand" excludeFromHelp=true {
	
	function run()  {
		
		print.line();
		print.yellowLine( 'General help and description of how to use cachebox create' );
		print.line();
		print.line();
		
		shell.callCommand( "help cachebox create" );

	}
}