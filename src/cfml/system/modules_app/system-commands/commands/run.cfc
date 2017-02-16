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
/*
		var executeResult 	= "";
		var executeError 	= "";*/
		
		// Prep the command to run in the OS-specific shell
		if( fileSystemUtil.isWindows() ) {
			// Pass through Windows' command shell, /a outputs ANSI formatting, /c runs as a command
			var commandArray = [ 'cmd','/a','/c', arguments.command ];
		} else {
			// Pass through bash in interactive mode with -i to expand aliases like "ll".
			// -c runs input as a command, "&& exits" cleanly from the shell as long as the original command ran successfully
			var nativeShell = configService.getSetting( 'nativeShell', '/bin/bash' );
			commandArray = [ nativeShell,'-i','-c', arguments.command & ' && exit' ];
		}
		
		try{
            // grab the current working directory
            var CWDFile = createObject( 'java', 'java.io.File' ).init( fileSystemUtil.resolvePath( '' ) );
            
			var exitCode = createObject( "java", "java.lang.ProcessBuilder" )
				.init( commandArray )
				// Do you believe in magic?
				.inheritIO()
				.directory( CWDFile )
				.start()
				.waitFor();
				
			// This works great on Windows.
			// On Linux, the standard input (keyboard) is not being piped to the background process.
			// Also on Linux, the word "exit" appears in the output. The output stream needs to be intercepted to clean it up.
			
			if( exitCode != 0 ) {
				error( 'Command returned failing exit code [#exitCode#]' );
			}
			
/*
            // execute the server command
            var process = createObject( 'java', 'java.lang.Runtime' )
                .getRuntime()
                .exec( '#commandArray#', javaCast( "null", "" ), CWDFile );
            var commandResult = createObject( 'java', 'lucee.commons.cli.Command' )
                .execute( process );
                
            // I don't like the idea of potentially removing significant whitespace, but commands like pwd
            // come with an extra line break that is a pain if you want to pipe into another command
            var executeResult = trim( commandResult.getOutput() );
            var executeError = trim( commandResult.getError() );

			// Output Results
			if( !isNull( executeResult ) && len( executeResult ) ) {
				print.Text( executeResult );
			}
			// Output error
			if( !isNull( executeError ) &&  len( executeError ) ) {				
				// Clean up standard error from Unix interactive shell workaround
				if( !fileSystemUtil.isWindows() && right( executeError, 4 ) == 'exit' ) {
				        executeError = mid( executeError, 1, len( executeError )-4 );
				}
				// Clean up annoying warnings abour job control in some shells.
				if( !fileSystemUtil.isWindows() && findNoCase( 'bash: no job control in this shell', executeError ) ) {
					executeError = replaceNoCase( executeError, 'bash: no job control in this shell', '' );
					executeError = trim( executeError );					
				}
				print.redText( executeError );
			}*/

		} catch (any e) {
			error( '#e.message##CR##e.detail#' );
		}

	}

}
