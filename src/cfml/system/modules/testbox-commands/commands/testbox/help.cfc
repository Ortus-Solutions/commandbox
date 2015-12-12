component extends="commandbox.system.BaseCommand" excludeFromHelp=true {
	
	function run()  {
		
		print.line();
		print.yellow( 'The ' ); print.boldYellow( 'testbox' ); print.yellowLine( ' namespace helps you do anything related to your TestBox isntallation. Use these commands' );
		print.yellowLine( 'to create tests, generate runners, and even run your tests for you from the command line.' );
		
		print.yellowLine( 'Type help before any command name to get additional information on how to call that specific command.' );
		
		print.line();
		print.line();
		

	}
}