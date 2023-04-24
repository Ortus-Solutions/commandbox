/**
 * Execute an operating system level command in the native shell.  The binary must be in the PATH, or you can specify the full
 * path to it.  This command will wait for the OS executable to complete but will flush the output as it is received.
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
	property name="fileSystemUtil" inject="fileSystem";
	property name="configService" inject="configService";

	/**
	* @command.hint The full operating system command to execute including the binary and any parameters
	**/
	function run(
		required command
	){
		var interactive = !systemsettings.getSystemSetting( 'box_currentCommandPiped', false );

		// Check and see if input was piped in along with a command like so:
		// #createguid | !clip
		if( arguments.keyExists( '2' ) ) {
			// If so, take the first arg as the piped data
			// and the second param is the actual command
			var piped = arguments.command;
			interactive = false;
			arguments.command = arguments[2];
		}

        var terminal = shell.getReader().getTerminal();
		var nativeShell = fileSystemUtil.getNativeShell();
		// Prep the command to run in the OS-specific shell
		if( fileSystemUtil.isWindows() ) {
			// Pass through Windows' command shell, /a outputs ANSI formatting, /c runs as a command
			var commandArray = [ nativeShell,'/a','/c', arguments.command ];
		} else {
			// Pass through bash in interactive mode with -i to expand aliases like "ll".
			// -c runs input as a command, "&& exits" cleanly from the shell as long as the original command ran successfully
			commandArray = [ nativeShell, '-i', '-c', arguments.command & ' 2>&1; ( exit $? > /dev/null )' ];
		}

		if( configService.getSetting( 'debugNativeExecution', false ) ) {
			print.line( commandArray.tolist( ' ' ) ).toConsole();
		}

		var exitCode = 1;
        // grab the current working directory
        var CWDFile = createObject( 'java', 'java.io.File' ).init( resolvePath( '' ) );

		try{

            // This unbinds JLine from our input and output so it's not fighting over the keyboard
            terminal.pause();
            var processBuilder = createObject( "java", "java.lang.ProcessBuilder" ).init( commandArray );

            // incorporate CommandBox environment variables into the process's env
            var currentEnv = processBuilder.environment();
            currentEnv.putAll( systemSettings.getAllEnvironmentsFlattened().map( (k, v)=>toString(v) ) );

            // Special check to remove ConEMU vars which can screw up the sub process if it happens to run cmd, such as opening VSCode.
            if( fileSystemUtil.isWindows() && currentEnv.containsKey( 'ConEmuPID' ) ) {
	            for( var key in currentEnv ) {
	            	if( key.startsWith( 'ConEmu' ) || key == 'PROMPT' ) {
	            		currentEnv.remove( key );
	            	}
	            }
	        }

			if( interactive ) {

				var process = processBuilder
					// Do you believe in magic
					// This works great on Mac/Windows.
					// On Linux, the standard input (keyboard) is not being piped to the background process.
					.inheritIO()
					// Sets current working directory for the process
					.directory( CWDFile )
					// Fires process async
					.start();

				// waits for it to exit, returning the exit code
				var exitCode = process.waitFor();

			} else {

	            // Static reference to inner class
	            var redirect = createObject( 'java', 'java.lang.ProcessBuilder$Redirect' );
	            // A string builder to collect the output that we're also streaming to the console so it can be captured and piped to another command as well.
	            var processOutputStringBuilder = createObject( 'java', 'java.lang.StringBuilder' ).init( '' );
				processBuilder
					.redirectErrorStream(fileSystemUtil.isWindows())
					// Sets current working directory for the process
					.directory( CWDFile );

				if( isNull( piped ) ) {
					// Keyboard pipes through to the input of the process
					processBuilder = processBuilder.redirectInput( redirect.INHERIT );
				}

				if(!fileSystemUtil.isWIndows()) {
					processBuilder=processBuilder.redirectError(redirect.INHERIT);
				}
				// Fires process async
				process=processBuilder.start();

				// If we have piped input, feed it into the process (remember the "output" stream is the stdin of the process!
				if( !isNull( piped ) ) {
					var bufferedWriter = createObject( 'java', 'java.io.BufferedWriter' ).init( createObject( 'java', 'java.io.OutputStreamWriter' ).init( process.getOutputStream() ) );
					bufferedWriter.write( piped );
					bufferedWriter.close();
				}

				// Despite the name, this is the stream that the *output* of the external process is in.
				var inputStream = process.getInputStream();
				// I convert the byte array in the piped input stream to a character array
				var inputStreamReader = createObject( 'java', 'java.io.InputStreamReader' ).init( inputStream );

				var interruptCount = 0;
				// This will block/loop until the input stream closes, which means this loops until the process ends.
				while( ( var char = inputStreamReader.read() ) != -1 ) {
					if( ++interruptCount > 1000 ) {
						checkInterrupted();
						interruptCount=0;
					}
					// if running non-interactive, gather the output of the command
					processOutputStringBuilder.append( javaCast( 'char', char ) );
				}

				// make sure it's dead
				process.waitFor();

				// Get the exit code
				exitCode = process.exitValue();

				// This was non-interactive, print out the text output all at once.
				print.text( processOutputStringBuilder.toString() );
			}

			// As you were, JLine
            terminal.resume();

		} finally {

			// Clean up the streams
			if( !isNull( inputStream ) ) {
				inputStream.close();
			}

			// Clean up the streams
			if( !isNull( inputStreamReader ) ) {
				inputStreamReader.close();
			}

			// I had issues with Ctrl-C not fully exiting cmd on Windows.  This should make sure it's dead.
			if( !isNull( process ) ) {
				process.destroy();
			}

			// As you were, JLine
			if( terminal.paused() ) {
				terminal.resume();
			}

			checkInterrupted();
		}

		if( exitCode != 0 ) {
			error( message='Command returned failing exit code [#exitCode#]', exitCode=exitCode );
		}

	}

}
