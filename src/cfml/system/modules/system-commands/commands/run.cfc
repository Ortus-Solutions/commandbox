/**
 * Execute an operation system level command.  This command will wait for the OS exectuable to complete
 * .
 * {code:bash}
 * run myApp.exe
 * {code}
 * .
 * A shortcut for running OS binaries is to prefix the binary with "!".  In this mode, any other params need to be positional.
  * .
 * {code:bash}
 * !myApp.exe
 * !cmd /c dir
 * !cmd /c npm ll 10
 * {code}
 * .
 * Executing Java would look like this
 * .
 * {code:bash}
 * run java -jar myLib.jar
 * {code}
 *
 **/
component{

	/**
	* @command.hint The full operating system command to execute including the binary and any parameters
	**/
	function run(
		required command
	){

		var executeResult 	= "";
		var executeError 	= "";
	/*	
		// Prep the command to run in the OS-specific shell
		if( fileSystemUtil.isWindows() ) {
			arguments.command = 'cmd /a /c ' & arguments.command;
		} else {
			arguments.command = 'bash -i -c ' & arguments.command;
		}*/
		
		print.boldYellowLine( arguments.command );

		try{
            // grab the current working directory
            var pwd = fileSystemUtil.resolvePath( '' );
            var CWD = createObject( 'java', 'java.io.File' ).init( pwd );

            // execute the server command
            var process = createObject( 'java', 'java.lang.Runtime' )
                .getRuntime()
                .exec( '#arguments.command#', javaCast( "null", "" ), CWD );
            var commandResult = createObject( 'java', 'lucee.commons.cli.Command' )
                .execute( process );
            var executeResult = commandResult.getOutput();
            var executeError = commandResult.getError();

			// Output Results
			if( !isNull( executeResult ) && len( executeResult ) ) {
				print.line( executeResult );
			}
			// Output error
			if( !isNull( executeError ) &&  len( executeError ) ) {
				print.redLine( executeError );
			}

		} catch (any e) {
			error( '#e.message##CR##e.detail#' );
		}

	}

}
