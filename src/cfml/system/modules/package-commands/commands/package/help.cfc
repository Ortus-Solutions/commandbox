component extends="commandbox.system.BaseCommand" excludeFromHelp=true {
	
	function run()  {
		
		print.line();
		print.yellow( 'The ' ); print.boldYellow( 'package' ); print.yellowLine( ' namespace is for dealing with packages and their box.json descriptor file' );
		print.yellowLine( 'Use these commands to initialize a package, set, and retreive values from the box.json descriptor.' );
		print.yellowLine( 'Type help before any command name to get additional information on how to call that specific command.' );
		
		print.line();
		print.line();

	}
}