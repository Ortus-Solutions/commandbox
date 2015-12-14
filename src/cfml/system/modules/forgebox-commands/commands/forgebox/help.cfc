component excludeFromHelp=true {
	
	function run()  {
		
		print.line()
			.yellow( 'The ' ).boldYellow( 'forgebox' ).yellowLine( ' namespace helps you interact with the ForgeBox online code repo.' )
			.yellowLine( 'Use these commands to browse ForgeBox entries as well as download and install ForgeBox projects into your code.' )
			.yellowLine( 'You can also use these commands to manage your own ForgeBox entries.' )
			.yellow( 'To get started, look around by using the "' ).boldYellow( 'forgebox show' ).yellowLine( '" command to search the online repo.  Ex:' )
			.line()
			.magenta( '#print.tab#> ' ).yellowLine( 'forgebox show popular modules' )
			.magenta( '#print.tab#> ' ).yellowLine( 'forgebox show new interceptors' )
			.magenta( '#print.tab#> ' ).yellowLine( 'forgebox recent' )
			.magenta( '#print.tab#> ' ).yellowLine( 'forgebox show "slugName"' )
			.line()
			.yellowLine( 'Type help before any command name to get additional information on how to call that specific command.' )
			.line();

	}
}