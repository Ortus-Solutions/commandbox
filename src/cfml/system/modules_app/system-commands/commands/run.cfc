/**
 * Execute an operating system level command in the native shell.  The binary must be in the PATH, or you can specify the full 
 * path to it.  This command will wait for the OS exectuable to complete but will flush the output as it is received.
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
            
            var redirect = createObject( "java", "java.lang.ProcessBuilder$Redirect" );
			process = createObject( "java", "java.lang.ProcessBuilder" )
				.init( commandArray )
				// Assume CommandBox's standard input for this process
				.redirectInput( redirect.INHERIT )
				// Combine standard error and standard out
				.redirectErrorStream( true )				
				.directory( CWDFile )
				.start();
				
			// This works great on Windows.
			// On Linux, the standard input (keyboard) is not being piped to the background process.
			
		    // needs to be unique in each run to avoid errors
			var threadName = '#createUUID()#';
				
			// Spin up a thread to capture the standard out and error from the server
			thread name="#threadName#" {
				try{
					
		    		var inputStream = process.getInputStream();
		    		var inputStreamReader = createObject( 'java', 'java.io.InputStreamReader' ).init( inputStream );
		    		var bufferedReader = createObject( 'java', 'java.io.BufferedReader' ).init( inputStreamReader );
					
					// These two patterns need to be stripped off the output.
					var exit = 'exit';
					var jobControl = 'bash: no job control in this shell';
					
					var char = bufferedReader.read();
					var token = '';
					while( char != -1 ){
						token &= chr( char );
						
						// Only output if we arent matching any of the forbidden patterns above.
						if( !exit.startsWith( trim( token ) )
							&& !jobControl.startsWith( trim( token ) )
							&& !char == 13
							&& !char == 10 ) {
							// Build up our output
							print
								.text( token )
								.toConsole();
							
							token = '';
						}
						
						char = bufferedReader.read();
					} // End of inputStream
				
					// Output any trailing text as long as it isn't a match
					if( !trim( token ).startsWith( exit )
						&& !trim( token ).startsWith( jobControl )  ) {
						print
							.text( trim( token ) )
							.toConsole();
					}
					
				} catch( any e ) {
					logger.error( e.message & ' ' & e.detail, e.stacktrace );
					print.line( e.message & ' ' & e.detail, e.stacktrace );
				} finally {
					// Make sure we always close the file or the process will never quit!
					if( isDefined( 'bufferedReader' ) ) {
						bufferedReader.close();
					}
				}
			}
			
			var exitCode = process.waitFor();
			
			thread action="join" name="#threadName#";
			
			if( exitCode != 0 ) {
				error( 'Command returned failing exit code [#exitCode#]' );
			}			

		} catch (any e) {
			error( '#e.message##CR##e.detail#' );
		}

	}

}
