component extends="commandbox.system.BaseCommand" excludeFromHelp=true {
	
	function run()  {
		
		print.line();
		print.yellow( 'The ' ); print.boldYellow( 'coldbox create' ); print.yellowLine( ' namespace allows you to quickly scaffold applications ' );
		print.yellowLine( 'and individual app pieces.  Use these commands to stub out placeholder files' );
		print.yellow( 'as you plan your application.  Most commands create a single file, but "' ); print.boldYellow( 'coldbox create app' ); print.yellowLine( '"' );
		print.yellowLine( 'will generate an entire, working application into an empty folder for you. Type help before' );
		print.yellowLine( 'any command name to get additional information on how to call that specific command.' );
		
		print.line();
		print.line();
		

	}
}