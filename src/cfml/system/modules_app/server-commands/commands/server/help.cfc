component excludeFromHelp=true {

	function run()  {

		print.line()
		.yellow( 'The ' ).boldYellow( 'server' ).yellowLine( ' namespace contains commands that allow you to start, stop, ' )
		.yellowLine( 'and manage the embedded CFML server to run your code quickly and easily.' )
		.yellowLine( 'Each server will start in its own process and run until you stop it.' )
		.line()
		.line();

	}
}