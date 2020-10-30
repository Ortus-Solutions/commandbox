/**
* Exits out of the shell.  If the CommandBox binary was executed directly, the shell will close.  If the
* CommandBox binary was run from your OS's native shell, you will be returned there.
* .
* {code:bash}
* exit
* {code}
* .
* You can exit the shell with a specific exit code like this:
* .
* {code:bash}
* exit 1
* {code}
* .
* Please note, any embedded servers started during your session will continue to run as they are in a separate
* process.  Use the icon in your OS's command tray to interact with the servers, or start CommandBox back up
* at a later time and "cd" to the root folder of the server.
*
**/
component aliases="exit,q,e" {

	/**
	* @exitCode The exitCode for the box process to return
	*/
	function run( exitCode=0 )  {
		if( !isNumeric( exitCode ) ) {
			error( 'Exit code [#exitCode#] is invalid. Please supply a numeric input' );
		}
		setExitCode( exitCode );
		shell.exit();
	}

}
