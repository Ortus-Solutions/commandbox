/**
* This command waits for the user to press a key to continue.  You could use this in a boxr recipe
* to pause execution so you can see the previous commands' output before the windows closes if
* calling it from a shortcut to a native OS prompt that closes as soon as it's complete.
 * .
 * {code:bash}
 * pause
 * {code}
**/
component excludeFromHelp=true {


	function run()  {

		try {

			// A dumb terminal (no TTY, such as a server started as a service) can't read a key press,
			// so output the equivalent message and just sit and wait to be interrupted, same as the
			// server command does when starting a console server.  Nothing can be pressed here.
			if( shell.isTerminalDumb() ) {
				print.line( 'Waiting for interrupt' ).toConsole();
				while( true ) {
					sleep( 500 );
				}
			} else {
				waitForKey( 'Press any key to continue...' );
				print.line();
			}

		// An interrupt is a normal way for a pause to end-- don't blow up over it.
		// Ctrl-C arrives as UserInterruptException, Ctrl-D as EndOfFileException,
		// and an interrupted sleep() as a NativeException with the message "sleep interrupted"
		} catch( any e ) {
			var normalExit = [ 'UserInterruptException', 'EndOfFileException' ].findNoCase( e.type ?: '' )
				|| ( e.message ?: '' ).contains( 'interrupted' );

			if( !normalExit ) {
				rethrow;
			}
		}
	}


}
