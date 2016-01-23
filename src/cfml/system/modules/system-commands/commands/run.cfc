/**
 * Execute an operating system level command in the native shell.  The binary must be in the PATH, or you can specify the full 
 * path to it.  This command will wait for the OS exectuable to complete.   This cannot be used for any commands that require 
 * interactivity or don't exit automatically or the call will hang indefinitely.  
 * .
 * {code:bash}
 * run myApp.exe
 * run /path/to/myApp
 * {code}
 * .
 * A shortcut for running OS binaries is to prefix the binary with "!".  In this mode, any other params need to be positional.
 * There is no CommandBox parsing applied to the command's arguments.  They are passed straight to the native shell. 
 * .
 * {code:bash}
 * !myApp.exe
 * !/path/to/myApp
 * !dir
 * !npm ll
 * !ipconfig
 * !ping google.com -c 4
 * {code}
 * .
 * Executing Java would look like this
 * .
 * {code:bash}
 * !java -version
 * !java -jar myLib.jar
 * {code}
 * .
 * You can even call other CLIs
 * .
 * {code:bash}
 * !git init
 * touch index.cfm
 * !git add .
 * !git commit -m "Initial Commit"
 * {code}
 *
 **/
component{
	
	property name="configService" inject="configService";

	/**
	* @command.hint The full operating system command to execute including the binary and any parameters
	**/
	function run(
		required command
	){

		var executeResult 	= "";
		var executeError 	= "";
		
		// Prep the command to run in the OS-specific shell
		if( fileSystemUtil.isWindows() ) {
			// Pass through Windows' command shell, /a outputs ANSI formatting, /c runs as a command
			arguments.command = [ 'cmd','/a','/c', arguments.command ];
		} else {
			// Pass through bash in interactive mode to expand aliases like "ll".
			// -c runs input as a command, && exists cleanly from the shell as long as the original command ran successfully
			var nativeShell = configService.getSetting( 'nativeShell', '/bin/bash' );
			arguments.command = [ nativeShell,'-i','-c', arguments.command & '&& exit'];
		}
		
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
            var executeResult = trim( commandResult.getOutput() );
            var executeError = trim( commandResult.getError() );

			// Output Results
			if( !isNull( executeResult ) && len( executeResult ) ) {
				print.line( executeResult );
			}
			// Output error
			if( !isNull( executeError ) &&  len( executeError ) ) {
				
				// Clean up standard error from Unix interactive shell workaround
				if( !fileSystemUtil.isWindows() && right( executeError, 4 ) == 'exit' ) {
				        executeError = mid( executeError, 1, len( executeError )-4 );
				}
				
				print.redLine( executeError );
			}

		} catch (any e) {
			error( '#e.message##CR##e.detail#' );
		}

	}

}
