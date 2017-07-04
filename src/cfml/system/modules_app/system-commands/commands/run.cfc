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
			commandArray = [ nativeShell, '-i', '-c', arguments.command & ' && ( exit $? > /dev/null )' ];
		}

		try{
            // grab the current working directory
            var CWDFile = createObject( 'java', 'java.io.File' ).init( fileSystemUtil.resolvePath( '' ) );
			var exitCode = createObject( "java", "java.lang.ProcessBuilder" )
				.init( commandArray )
				// Do you believe in magic
				// This works great on Mac/Windows.
				// On Linux, the standard input (keyboard) is not being piped to the background process.
				.inheritIO()
				// Sets current working directory for the process
				.directory( CWDFile )
				// Fires process async
				.start()
				// waits for it to exit, returning the exit code
				.waitFor();

			if( exitCode != 0 ) {
				error( 'Command returned failing exit code [#exitCode#]' );
			}

		} catch( any e ){
			error( '#e.message##CR##e.detail#' );
		}

	}

}