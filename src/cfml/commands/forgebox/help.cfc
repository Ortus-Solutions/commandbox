component extends="commandbox.system.BaseCommand" excludeFromHelp=true {
	
	function run()  {
		
		print.line();
		print.yellow( 'The ' ); print.boldYellow( 'forgebox' ); print.yellowLine( ' namespace helps you interact with the ForgeBox online code repo.' );
		print.yellowLine( 'Use these commands to browse ForgeBox entries as well as download and install ForgeBox projects into your code.' );
		print.yellowLine( 'You can also use these commands to manage your own ForgeBox entries.' );
		print.yellow( 'To get started, look around by using the "' ); print.boldYellow( 'forgebox show' ); print.yellowLine( '" command to search the online repo.  Ex:' );
		print.line();
		print.magenta( '  > ' ); print.yellowLine( 'forgebox show popular modules' );
		print.magenta( '  > ' ); print.yellowLine( 'forgebox show new interceptors' );
		print.magenta( '  > ' ); print.yellowLine( 'forgebox recent' );
		print.magenta( '  > ' ); print.yellowLine( 'forgebox show "slugName"' );
		print.line();
		print.yellowLine( 'Type help before any command name to get additional information on how to call that specific command.' );
		
		print.line();
		print.line();

		

	}
}