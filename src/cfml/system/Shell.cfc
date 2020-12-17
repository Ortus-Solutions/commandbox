/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
* The CommandBox Shell Object that controls the shell
*/
component accessors="true" singleton {

	// DI
	property name="commandService" 			inject="CommandService";
	property name="CommandCompletor" 		inject="CommandCompletor";
	property name="REPLCompletor" 			inject="REPLCompletor";
	property name="readerFactory" 			inject="ReaderFactory";
	property name="print" 					inject="print";
	property name="cr" 						inject="cr@constants";
	property name="formatterUtil" 			inject="Formatter";
	property name="logger" 					inject="logbox:logger:{this}";
	property name="fileSystem"				inject="FileSystem";
	property name="WireBox"					inject="wirebox";
	property name="LogBox"					inject="logbox";
	property name="InterceptorService"		inject="InterceptorService";
	property name="ModuleService"			inject="ModuleService";
	property name="Util"					inject="wirebox.system.core.util.Util";
	property name="CommandHighlighter"	 	inject="CommandHighlighter";
	property name="REPLHighlighter"			inject="REPLHighlighter";
	property name="configService"			inject="configService";
	property name='systemSettings'			inject='SystemSettings';

	/**
	* The java jline reader class.
	*/
	property name="reader";
	/**
	* The shell version number
	*/
	property name="version";
	/**
	* The loader version number
	*/
	property name="loaderVersion";
	/**
	* Bit that tells the shell to keep running
	*/
	property name="keepRunning" default="true" type="Boolean";
	/**
	* Bit that is used to reload the shell
	*/
	property name="reloadShell" default="false" type="Boolean";
	/**
	* Clear screen after reload
	*/
	property name="doClearScreen" default="false" type="Boolean";
	/**
	* The Current Working Directory
	*/
	property name="pwd";
	/**
	* The default shell prompt
	*/
	property name="shellPrompt";
	/**
	* This value is either "interactive" meaning the shell stays open waiting for user input
	* or "command" which means a single command will be run and then the shell will be exiting.
	* This differentiation may be useful for commands who want to be careful not to leave threads running
	* that they expect to finish since the JVM will terminiate immedatley after the command finishes.
	* This could also be useful to reduce the amount of extra text that's output such as the CommandBox
	* banner which isn't really needed for a one-off command, especially if the output of that command needs
	* to be fed into another OS command.
	*/
	property name="shellType" default="interactive";


	/**
	 * constructor
	 * @inStream.hint input stream if running externally
	 * @outputStream.hint output stream if running externally
	 * @userDir.hint The user directory
	 * @userDir.inject userDir@constants
	 * @tempDir.hint The temp directory
	 * @tempDir.inject tempDir@constants
 	**/
	function init(
		any inStream,
		any outputStream,
		required string userDir,
		required string tempDir,
		boolean asyncLoad=true
	){
		variables.currentThread = createObject( 'java', 'java.lang.Thread' ).currentThread();

		// Possible byte order marks
		variables.BOMS = [
			chr( 254 ) & chr( 255 ),
			chr( 255 ) & chr( 254 ),
			chr( 239 ) & chr( 187 ) & chr( 191 ),
			chr( 00 ) & chr( 254 ) & chr( 255 ),
			chr( 255 ) & chr( 254 ) & chr( 00 )
		];

		// Version is stored in cli-build.xml. Build number is generated by Ant.
		// Both are replaced when CommandBox is built.
		variables.version = "@build.version@+@build.number@";
		variables.loaderVersion = "@build.LoaderVersion@";
		// Init variables.
		variables.keepRunning 	= true;
		variables.reloadshell 	= false;
		variables.pwd 			= "";
		variables.reader 		= "";
		variables.shellPrompt 	= "";
		variables.userDir 	 	= arguments.userDir;
		variables.tempDir 		= arguments.tempDir;

		// Save these for onDIComplete()
		variables.initArgs = arguments;

		// If reloading the shell
		if( structKeyExists( request, 'lastCWD' ) ) {
			// Go back where we were
			variables.pwd= request.lastCWD;
		} else {
			// Store incoming current directory
			variables.pwd = variables.userDir;
		}

		setShellType( 'interactive' );

    	return this;
	}

	/**
	 * Finish configuring the shell
	 **/
	function onDIComplete() {
		// Create reader console and setup the default shell Prompt
		variables.reader 		= readerFactory.getInstance( argumentCollection = variables.initArgs  );
		variables.shellPrompt 	= print.green( "CommandBox> ");

		// Create temp dir & set
		setTempDir( variables.tempdir );

		getInterceptorService().configure();
		getModuleService().configure();

		// When the shell first starts, the current working dir doesn't always containt the trailing slash
		variables.pwd = fileSystem.resolvePath( variables.pwd );

		getModuleService().activateAllModules();

		// load commands
		if( variables.initArgs.asyncLoad ){
			thread name="commandbox.loadcommands#getTickCount()#"{
				variables.commandService.configure();
			}
		} else {
			variables.commandService.configure();
		}
	}


	/**
	 * Exists the shell
	 **/
	Shell function exit() {
    	variables.keepRunning = false;

		return this;
	}

	/**
	 * Sets the OS Exit code to be used
	 **/
	Shell function setExitCode( required string exitCode ) {
		createObject( 'java', 'java.lang.System' ).setProperty( 'cfml.cli.exitCode', arguments.exitCode );
		// Keep a more readable version in sync for people to acces via the shell
		createObject( 'java', 'java.lang.System' ).setProperty( 'exitCode', exitCode );
		return this;
	}

	/**
	 * Gets the last Exit code to be used
	 **/
	function getExitCode() {
		return (createObject( 'java', 'java.lang.System' ).getProperty( 'cfml.cli.exitCode' ) ?: 0);

	}


	/**
	 * Sets reload flag, relaoded from shell.cfm
	 * @clear.hint clears the screen after reload
 	 **/
	Shell function reload( Boolean clear=true ){

		setDoClearScreen( arguments.clear );
		setReloadshell( true );
    	setKeepRunning( false );

    	return this;
	}

	/**
	 * Returns the current console text
 	 **/
	string function getText() {
    	return variables.reader.getCursorBuffer().toString();
	}

	/**
	 * Sets the shell prompt
	 * @text.hint prompt text to set, if empty we use the default prompt
 	 **/
	Shell function setPrompt( text="" ) {
		if( !len( arguments.text ) ){
			variables.shellPrompt = print.green( "CommandBox:#listLast( getPWD(), "/\" )#> " );
		} else {
			variables.shellPrompt = arguments.text;
		}
		//variables.reader.setPrompt( variables.shellPrompt );
		return this;
	}

	/**
	 * ask the user a question and wait for response
	 * @message.hint message to prompt the user with
	 * @mask.hint When not empty, keyboard input is masked as that character
	 * @defaultResponse Text to populate the buffer with by default that will be submitted if the user presses enter without typing anything
	 * @keepHistory True to remeber the text typed in the shell history
	 *
	 * @return the response from the user
 	 **/
	string function ask( message, string mask='', string defaultResponse='', keepHistory=false, highlight=false, complete=false ) {

		try {

			if( !highlight ) {
				enableHighlighter( false );
			}

			if( !complete ) {
				enableCompletion( false );
			}

			// Some things are best forgotten
			if( !keepHistory ) {
				enableHistory( false );
			}

			var terminal = getReader().getTerminal();
			if( terminal.paused() ) {
				terminal.resume();
			}

			// read reponse while masking input
			var input = variables.reader.readLine(
				// Prompt for the user
				arguments.message,
				// Optionally mask their input
				len( arguments.mask ) ? javacast( "char", left( arguments.mask, 1 ) ) : javacast( "null", '' ),
				// This won't work until we can upgrade to Jline 2.14
				// Optionally pre-fill a default response for them
				len( arguments.defaultResponse ) ? javacast( "String", arguments.defaultResponse ) : javacast( "null", '' )
			);

		// user wants to exit this command, they've pressed Ctrl-C
		} catch( org.jline.reader.UserInterruptException var e ) {
			throw( message='CANCELLED', type="UserInterruptException");
		// user wants to exit the entire shell, they've pressed Ctrl-D
		} catch( org.jline.reader.EndOfFileException var e ) {
			// This should probably just read what is currently on the buffer,
			// but JLine doesn't give me a way to get that currently
			throw( message='EOF', type="EndOfFileException");
		} finally{
			// Reset back to default prompt
			setPrompt();
			// Turn history back on
			enableHistory();

			if( !complete ) {
				enableCompletion( true );
			}

			if( !highlight ) {
				enableHighlighter( true );
			}
		}

		return input;
	}

	/**
	 * Ask the user a question looking for a yes/no response
	 * @message.hint message to prompt the user with
	 *
	 * @return the response from the user as a boolean value
 	 **/
	boolean function confirm( required message ){
		var answer = ask( "#message# : " );
		if( isNull( answer ) ){ return false; }
		if( trim( answer ) == "y" || ( isBoolean( answer ) && answer ) ) {
			return true;
		}
		return false;
	}

	function getMainThread() {
		return variables.currentThread;
	}

	/**
	 * Wait until the user's next keystroke, returns the key pressed
	 * @message.message An optional message to display to the user such as "Press any key to continue."
	 *
	 * @return character of key pressed or key binding name.
 	 **/
	string function waitForKey( message='' ) {
		var key = '';
		if( len( arguments.message ) ) {
			printString( arguments.message );
		}

		var terminal = getReader().getTerminal();
		if( terminal.paused() ) {
				terminal.resume();
		}

		var keys = createObject( 'java', 'org.jline.keymap.KeyMap' );
		var capability = createObject( 'java', 'org.jline.utils.InfoCmp$Capability' );
		var bindingReader = createObject( 'java', 'org.jline.keymap.BindingReader' ).init( terminal.reader() );

		// left, right, up, down arrow
		keys.bind( capability.key_left.name(), keys.key( terminal, capability.key_left ) );
		keys.bind( capability.key_right.name(), keys.key( terminal, capability.key_right ) );
		keys.bind( capability.key_up.name(), keys.key( terminal, capability.key_up ) );
		keys.bind( capability.key_down.name(), keys.key( terminal, capability.key_down ) );
		keys.bind( capability.back_tab.name(), keys.key( terminal, capability.back_tab ) );

		// Home/end
		keys.bind( capability.key_home.name(), keys.key( terminal, capability.key_home ) );
		keys.bind( capability.key_end.name(), keys.key( terminal, capability.key_end ) );

		// delete key/delete line/backspace
		keys.bind( capability.key_dc.name(), keys.key( terminal, capability.key_dc ) );
		// Not sure why, but throwing unsupported exception on Linux
		// keys.bind( capability.key_backspace.name(), keys.key( terminal, capability.key_backspace ) );

		keys.bind( capability.key_ic.name(), keys.key( terminal, capability.key_ic ) );

		// Page up/down
		keys.bind( capability.key_npage.name(), keys.key( terminal, capability.key_npage ) );
		keys.bind( capability.key_ppage.name(), keys.key( terminal, capability.key_ppage ) );

		// Function keys
		keys.bind( capability.key_f1.name(), keys.key( terminal, capability.key_f1 ) );
		keys.bind( capability.key_f2.name(), keys.key( terminal, capability.key_f2 ) );
		keys.bind( capability.key_f3.name(), keys.key( terminal, capability.key_f3 ) );
		keys.bind( capability.key_f4.name(), keys.key( terminal, capability.key_f4 ) );
		keys.bind( capability.key_f5.name(), keys.key( terminal, capability.key_f5 ) );
		keys.bind( capability.key_f6.name(), keys.key( terminal, capability.key_f6 ) );
		keys.bind( capability.key_f7.name(), keys.key( terminal, capability.key_f7 ) );
		keys.bind( capability.key_f8.name(), keys.key( terminal, capability.key_f8 ) );
		keys.bind( capability.key_f9.name(), keys.key( terminal, capability.key_f9 ) );
		keys.bind( capability.key_f10.name(), keys.key( terminal, capability.key_f10 ) );
		keys.bind( capability.key_f11.name(), keys.key( terminal, capability.key_f11 ) );
		keys.bind( capability.key_f12.name(), keys.key( terminal, capability.key_f12 ) );

		// Everything else
		keys.setnomatch( 'self-insert' );

		// This doesn't seem to work on Windows
		keys.bind( 'delete', keys.del() );

		keys.bind( 'escape', keys.esc() );
		keys.setAmbiguousTimeout( 50 );


		try {
			// Next 3 lines required for this to work on *nix
			attr = terminal.enterRawMode();
			terminal.puts( capability.keypad_xmit, [] );
			terminal.flush();

			var binding = bindingReader.readBinding( keys );

		} catch (any e) {
			if( e.getPageException().getRootCause().getClass().getName() == 'java.io.InterruptedIOException' ) {
				throw( message='CANCELLED', type="UserInterruptException");
			}
			rethrow;
		} finally {
			// Undo the rawmode stuff above
			if( !isNull( attr ) ) {
				terminal.setAttributes( attr );
			}
			terminal.puts( capability.keypad_local, [] );
			terminal.flush();
		}

		if( binding == 'self-insert' ) {
			key = bindingReader.getLastBinding();
		} else {
			key = binding;
		}

		// Reset back to default prompt
		setPrompt();

		return key;
	}

	/**
	 * clears the console
	 *
	 * @note Almost works on Windows, but doesn't clear text background
	 *
 	 **/
	Shell function clearScreen() {
		reader.clearScreen();
   		variables.reader.getTerminal().writer().flush();
		return this;
	}

	/**
	 * Get's terminal width
  	 **/
	function getTermWidth() {
       	return variables.reader.getTerminal().getWidth();
	}

	/**
	 * Get's terminal height
  	 **/
	function getTermHeight() {
       	return variables.reader.getTerminal().getHeight();
	}

	/**
	 * Alias to get's current directory or use getPWD()
  	 **/
	function pwd() {
    	return variables.pwd;
	}

	/**
	* Get the temp dir in a safe manner
	*/
	string function getTempDir(){
		return variables.tempDir;
	}

	/**
	 * sets and renews temp directory
	 * @directory.hint directory to use
  	 **/
	Shell function setTempDir( required directory ){

       // Create it if it's not there.
       if( !directoryExists( arguments.directory ) ) {
	        directoryCreate( arguments.directory );
       }

    	// set now that it is created.
    	variables.tempdir = arguments.directory;

    	return this;
	}

	/**
	 * Changes the current directory of the shell and returns the directory set.
	 * @directory.hint directory to CD to.  Please verify it exists before calling.
  	 **/
	String function cd( directory="" ){
		variables.pwd = arguments.directory;
		request.lastCWD = arguments.directory;
		// Update prompt to reflect directory change
		setPrompt();
		return variables.pwd;
	}

	/**
	 * Prints a string to the reader console with auto flush
	 * @string.hint string to print (handles complex objects)
  	 **/
	Shell function printString( required string ){
		if( !isSimpleValue( arguments.string ) ){
			// TODO: is this even in use?? replace with shell.printString() if so
			systemOutput( "[COMPLEX VALUE]\n" );
			writedump(var=arguments.string, output="console");
			arguments.string = "";
		}
		// Pass string through JLine for color rounding, etc
		// This allows crappy 16 color terminals like Windows cmd to still show the "closest" color when using 256 color output
		string = createObject("java","org.jline.utils.AttributedString").fromAnsi( string ).toAnsi( variables.reader.getTerminal() );
    	variables.reader.getTerminal().writer().print( arguments.string );
    	variables.reader.getTerminal().writer().flush();

    	return this;
	}

	/**
	 * Runs the shell thread until exit flag is set
	 * @silent Supress prompt
  	 **/
    Boolean function run( silent=false ) {
		// init reload to false, just in case
        variables.reloadshell = false;

		try{

	        // setup bell enabled + keep running flags
	        // variables.reader.setBellEnabled( true );
	        variables.keepRunning = true;

	        var line ="";

			// while keep running
	        while( variables.keepRunning ){

				try {

					var interceptData = { prompt : variables.shellPrompt };
					getInterceptorService().announceInterception( 'prePrompt', interceptData );

					if( arguments.silent ) {
						interceptData.prompt = '';
					}

					var terminal = getReader().getTerminal();
					if( terminal.paused() ) {
						terminal.resume();
					}

					// Shell stops on this line while waiting for user input
			        if( arguments.silent ) {
			        	line = variables.reader.readLine( interceptData.prompt, javacast( "char", ' ' ) );
					} else {
			        	line = variables.reader.readLine( interceptData.prompt );
					}

				// User hits Ctrl-C.  Don't let them exit the shell.
				} catch( org.jline.reader.UserInterruptException var e ) {
					variables.reader.getTerminal().writer().print( variables.print.yellowLine( 'Use the "exit" command or Ctrl-D to leave this shell.' ) );
		    		variables.reader.getTerminal().writer().flush();
		    		continue;

				// User hits Ctrl-D.  Murder the shell dead.
				} catch( org.jline.reader.EndOfFileException var e ) {

					// e.getPageException().getException().getPartialLine()

					// Only output this if a user presses Ctrl-D, EOF can also happen if piping an actual file of input into the shell.
					if( !arguments.silent ) {
						variables.reader.getTerminal().writer().print( variables.print.boldGreenLine( 'Goodbye!' ) );
		    			variables.reader.getTerminal().writer().flush();
					}

					variables.keepRunning = false;
		    		continue;

				// Catch all for custom user interrupt thrown from CFML
				} catch( any var e ) {

					if( e.type.toString() == 'UserInterruptException' ) {
			    		continue;
					} else {
						rethrow;
					}

				}

	        	// If the standard input isn't avilable, bail.  This happens
	        	// when commands are piped in and we've reached the end of the piped stream
	        	if( !isDefined( 'line' ) ) {
	        		return false;
	        	}

	        	// Clean BOM from start of text in case something was piped from a file
	        	BOMS.each( function( i ){
	        		if( line.startsWith( i ) ) {
	        			line = replace( line, i, '' );
	        		}
	        	} );

	            // If there's input, try to run it.
				if( len( trim( line ) ) ) {
					var interceptData = {
						line : line
					}
					interceptorService.announceInterception( 'preProcessLine', interceptData );
					line = interceptData.line;

					callCommand( command=line, initialCommand=true );

					interceptorService.announceInterception( 'postProcessLine', interceptData );
				}

	        } // end while keep running

		} catch( any e ){
			printError( e );
		}

		return variables.reloadshell;
    }

	/**
	* Shutdown the shell and close/release any resources associated.
	* This isn't guaranteed to run if the shell is closed, but it
	* will run for a reload command
	*/
	function shutdown() {
		variables.reader.getTerminal().close();
	}

	/**
	* Call this method periodically in a long-running task to check and see
	* if the user has hit Ctrl-C.  This method will throw an UserInterruptException
	* which you should not catch.  It will unroll the stack all the way back to the shell
	*/
	function checkInterrupted( thisThread ) {
		if( isNull( arguments.thisThread ) ) {
			thisThread = createObject( 'java', 'java.lang.Thread' ).currentThread();
		}

		// Has the user tried to interrupt this thread?
		if( thisThread.isInterrupted() ) {
			// This clears the interrupted status. i.e., "yeah, yeah, I'm on it!"
			thisThread.interrupted();
			throw( 'UserInterruptException', 'UserInterruptException', '' );
		}
	}

	/**
	* @filePath The path to the history file to set
	*
	* Use this wrapper method to change the history file in use by the shell.
	*/
	function setHistory( filePath ) {

		var LineReader = createObject( "java", "org.jline.reader.LineReader" );

		// Save current file
		variables.reader.getHistory().save();
		// Swap out the file setting
		variables.reader.setVariable( LineReader.HISTORY_FILE, filePath );
		// Load in the new file
		variables.reader.getHistory().load();

	}

	/**
	* @enable Pass true to enable, false to disable
	*
	* Enable or disables history in the shell
	*/
	function enableHistory( boolean enable=true ) {

		var LineReader = createObject( "java", "org.jline.reader.LineReader" );

		// Swap out the file setting
		variables.reader.setVariable( LineReader.DISABLE_HISTORY, !enable );
	}

	/**
	* @enable Pass true to enable, false to disable
	*
	* Enable or disables tab completion in the shell
	*/
	function enableCompletion( boolean enable=true ) {

		// DOESN'T WORK. NOT IMPLEMENTED IN JLINE!
		//var LineReader = createObject( "java", "org.jline.reader.LineReader" );
		// variables.reader.setVariable( LineReader.DISABLE_COMPLETION, !enable );

		if( enable ) {
			setCompletor( 'command' );
		} else {
			setCompletor( 'dummy' );
		}
	}

	/**
	* @CompletorName Pass "command", "repl", or "dummy"
	* @executor If using REPL completor, pass an optional executor for better completion results
	*
	* Set the shell's completor
	*/
	function setCompletor( string completorName, any executor ) {
		if( completorName == 'command' ) {
			variables.reader.setCompleter( createDynamicProxy( CommandCompletor, [ 'org.jline.reader.Completer' ] ) );
		} else if( completorName == 'repl' ) {

			REPLCompletor.setCurrentExecutor( arguments.executor ?: '' );
			var thisCompletor = createDynamicProxy( REPLCompletor, [ 'org.jline.reader.Completer' ] );
			variables.reader.setCompleter( thisCompletor );

		} else if( completorName == 'dummy' ) {
			variables.reader.setCompleter( createObject( 'java', 'org.jline.reader.impl.completer.NullCompleter' ) );
		} else {
			throw( 'Invalid completor name [#completorName#].  Valid names are "command", "repl", or "dummy".' );
		}
	}

	/**
	* @enable Pass true to enable, false to disable
	*
	* Enable or disables highlighting in the shell
	*/
	function enableHighlighter( boolean enable=true ) {
		if( enable ) {
			setHighlighter( 'command' );
		} else {
			// A dummy highlighter, or at least one that never seems to do anything...
			setHighlighter( 'dummy' );
		}
	}

	/**
	* @highlighterName Pass "command", "repl", or "dummy"
	*
	* Set the shell's highlighter
	*/
	function setHighlighter( string highlighterName ) {
		if( highlighterName == 'command' ) {
			variables.reader.setHighlighter( createDynamicProxy( CommandHighlighter, [ 'org.jline.reader.Highlighter' ] ) );
		} else if( highlighterName == 'repl' ) {
			variables.reader.setHighlighter( createDynamicProxy( REPLHighlighter, [ 'org.jline.reader.Highlighter' ] ) );
		} else if( highlighterName == 'dummy' ) {
			variables.reader.setHighlighter( createObject( 'java', 'org.jline.reader.impl.DefaultHighlighter' ) );
		} else {
			throw( 'Invalid highlighter name [#highlighterName#].  Valid names are "command", "repl", or "dummy".' );
		}
	}

	/**
	 * Call a command
 	 * @command.hint Either a string containing a text command, or an array of tokens representing the command and parameters.
 	 * @returnOutput.hint True will return the output of the command as a string, false will send the output to the console.  If command outputs nothing, an empty string will come back.
 	 * @piped.hint Any text being piped into the command.  This will overwrite the first parameter (pushing any positional params back)
 	 * @initialCommand.hint Since commands can recursivley call new commands via this method, this flags the first in the chain so exceptions can bubble all the way back to the beginning.
 	 * In other words, if "foo" calls "bar", which calls "baz" and baz errors, all three commands are scrapped and do not finish execution.
 	 **/
	function callCommand(
		required any command,
		returnOutput=false,
		string piped,
		boolean initialCommand=false )  {

		var job = wirebox.getInstance( 'interactiveJob' );
		var progressBarGeneric = wirebox.getInstance( 'progressBarGeneric' );

		// Commands a loaded async in interactive mode, so this is a failsafe to ensure the CommandService
		// is finished.  Especially useful for commands run onCLIStart.  Wait up to 5 seconds.
		var i = 0;
		while( !CommandService.getConfigured() && ++i<50 ) {
			sleep( 100  );
		}

		// Flush history buffer to disk. I could do this in the quit command
		// but then I would lose everything if the user just closes the window
		variables.reader.getHistory().save();

		try{

			if( isArray( command ) ) {
				if( structKeyExists( arguments, 'piped' ) ) {
					var result = variables.commandService.runCommandTokens( arguments.command, piped, returnOutput );
				} else {
					var result = variables.commandService.runCommandTokens( tokens=arguments.command, captureOutput=returnOutput );
				}
			} else {
				var result = variables.commandService.runCommandLine( arguments.command, returnOutput );
			}

		// This type of error is recoverable-- like validation error or unresolved command, just a polite message please.
		} catch ( commandException var e) {
			// If this is a nested command, pass the exception along to unwind the entire stack.
			if( !initialCommand ) {
				rethrow;
			} else {

				progressBarGeneric.clear();
				if( job.isActive() ) {
					job.errorRemaining();
				}

				printError( { message : e.message, detail: e.detail } );
			}
		// This type of error means the user hit Ctrl-C, during a readLine() call. Duck out and move along.
		} catch ( UserInterruptException var e) {
			// If this is a nested command, pass the exception along to unwind the entire stack.
			if( !initialCommand ) {
				rethrow;
			} else {

				progressBarGeneric.clear();
				if( job.isActive() ) {
					job.errorRemaining();
				}
    			variables.reader.getTerminal().writer().flush();
				variables.reader.getTerminal().writer().println();
				variables.reader.getTerminal().writer().print( variables.print.boldRedLine( 'CANCELLED' ) );
			}

		} catch (any e) {
			// If this is a nested command, pass the exception along to unwind the entire stack.
			if( !initialCommand ) {
				rethrow;
			// This type of error means the user hit Ctrl-C, when not in a readLine() call (and hit my custom signal handler).  Duck out and move along.
			} else if( e.getPageException().getRootCause().getClass().getName() == 'java.lang.InterruptedException'
				|| e.type.toString() == 'UserInterruptException'
				|| e.message == 'UserInterruptException'
				|| e.type.toString() == 'EndOfFileException' ) {

				progressBarGeneric.clear();
				if( job.isActive() ) {
					job.errorRemaining();
				}

    			variables.reader.getTerminal().writer().flush();
				variables.reader.getTerminal().writer().println();
				variables.reader.getTerminal().writer().print( variables.print.boldRedLine( 'CANCELLED' ) );
			// Anything else is completely unexpected and means boom booms happened-- full stack please.
			} else {

				progressBarGeneric.clear();
				if( job.isActive() ) {
					job.errorRemaining( e.message );
					variables.reader.getTerminal().writer().println();
				}

				printError( e );
			}
		}

		// Return the output to the caller to deal with
		if( arguments.returnOutput ) {
			if( isNull( result ) ) {
				return '';
			} else {
				return result;
			}
		}

		var job = wirebox.getInstance( 'interactiveJob' );

		// We get to output the results ourselves
		if( !isNull( result ) && !isSimpleValue( result ) ){
			if( isArray( result ) ){
				return variables.reader.getTerminal().writer().printColumns( result );
			}
			result = variables.formatterUtil.formatJson( result );
			printString( result );
		} else if( !isNull( result ) && len( result ) ) {
			// If there is an active job, print our output through it
			if( job.getActive() ) {
				job.addLog( result )
			} else {
				printString( result );

				// If the command output text that didn't end with a line break one, add one
				var lastChar = mid( result, len( result ), 1 );
				if( ! ( lastChar == chr( 10 ) || lastChar == chr( 13 ) ) ) {
					variables.reader.getTerminal().writer().println();
				}
			}
		}

		return '';
	}


	/**
	 * Is the current terminal interactive?
	 * @returns boolean
  	 **/
	function isTerminalInteractive() {
		// Check for config setting called "nonInteractiveShell"
		if( configService.settingExists( 'nonInteractiveShell' ) && isBoolean( configService.getSetting( "nonInteractiveShell" ) ) ) {
			return !configService.getSetting( "nonInteractiveShell" );
		// Next check for an Environment Variable called "CI" that is set
		} else if( systemSettings.getSystemSetting( 'CI', '__NOT_SET__' ) != '__NOT_SET__' ) {
			return false;
		// Default to true
		} else {
			return true;
		}
	}

	/**
	 * print an error to the console
	 * @err.hint Error object to print (only message is required)
  	 **/
	Shell function printError( required err ){
		// Don't override a non-1 exit code.
		if( getExitCode() == 0 ) {
			setExitCode( 1 );
		}

		var verboseErrors = true;
		try{
			verboseErrors = configService.getSetting( 'verboseErrors', false );
		} catch( any var e ) {}

		// If CommandBox blows up while starting, the interceptor service won't be ready yet.
		if( getInterceptorService().getConfigured() ) {
			getInterceptorService().announceInterception( 'onException', { exception=err } );
		}

		variables.logger.error( '#arguments.err.message# #arguments.err.detail ?: ''#', arguments.err.stackTrace ?: '' );

		variables.reader.getTerminal().writer().print( variables.print.whiteOnRedLine( 'ERROR (#variables.version#)' ) );
		variables.reader.getTerminal().writer().println();
		variables.reader.getTerminal().writer().println( variables.print.boldRedText( variables.formatterUtil.HTML2ANSI( arguments.err.message, 'boldRed' ) ) );
		
		try{
			
			if( arguments.err.getClass().getName() == 'lucee.runtime.exp.CatchBlockImpl' ) {
				
				var rawJavaException = arguments.err.getPageException();
				var cause = rawJavaException.getCause();
				var indent = '  ';
				var previousType = '';
				var previousMessage = '';
				while( !isNull( cause ) ) {
					// If the nested exception has the same type as the outer exception and no message, there's no value in it here. (Lucee's nesting of IOExceptions can do this)
					// Or if there are two levels of causes with the same type and Message.  (RabbitMQ's Java client does this)
					if( (cause.getClass().getName() == arguments.err.message && isNull( cause.getMessage() ) )
						|| ( cause.getClass().getName() == previousType && previousMessage == cause.getMessage() ?: '' ) ) {
						// move the pointer and move on
						cause = cause.getCause();
						continue;
					}
					variables.reader.getTerminal().writer().println( variables.print.boldRedText( indent & 'caused by: ' & cause.getClass().getName() ) );
					previousType = cause.getClass().getName();
					// A Throwable's message can be null
					if( !isNull( cause.getMessage() ) ) {
						variables.reader.getTerminal().writer().println( variables.print.boldRedText( indent & cause.getMessage() ) );
						previousMessage = cause.getMessage();
					}
					// move the pointer and indent further
					cause = cause.getCause();
					indent &= '  ';
				}
				
			}
			
		// I don't to fubar the shell if the logic above fails.  This may never happen, but lets log it just in case it does.
		} catch( any e ) {			
			variables.reader.getTerminal().writer().print( variables.print.boldRedText( variables.formatterUtil.HTML2ANSI( 'Error getting root cause: #e.message# #e.detail#', 'boldRed' ) ) );
		}
		
		variables.reader.getTerminal().writer().println();

		if( structKeyExists( arguments.err, 'detail' ) ) {
			// If there's a tag context, this is likely a Lucee error and therefore has HTML in the detail
			if( structKeyExists( arguments.err, 'tagcontext' ) ) {
				variables.reader.getTerminal().writer().print( variables.print.boldRedText( variables.formatterUtil.HTML2ANSI( arguments.err.detail ) ) );
			} else {
				variables.reader.getTerminal().writer().print( variables.print.boldRedText( arguments.err.detail ) );
			}
			variables.reader.getTerminal().writer().println();
		}
		if( structKeyExists( arguments.err, 'tagcontext' ) ){
			var lines = arrayLen( arguments.err.tagcontext );
			if( lines != 0 ){
				for( var idx=1; idx <= lines; idx++) {
					var tc = arguments.err.tagcontext[ idx ];
					if( idx > 1 ) {
						variables.reader.getTerminal().writer().print( print.boldCyanText( "called from " ) );
					}
					if( verboseErrors ) {
						variables.reader.getTerminal().writer().print( variables.print.boldCyanText( "#tc.template#: line #tc.line##variables.cr#" ));
					} else {
						variables.reader.getTerminal().writer().print( variables.print.boldCyanText( "#tc.template.replaceNoCase( expandPath( '/CommandBox' ), '' )#: line #tc.line##variables.cr#" ));
					}
					if( len( tc.codeprinthtml ) && idx == 1 ){
						variables.reader.getTerminal().writer().print( variables.print.text( variables.formatterUtil.HTML2ANSI( tc.codeprinthtml ) ) );
					}
				}
			}
		}
		if( structKeyExists( arguments.err, 'stacktrace' ) ) {
			if( verboseErrors ) {
					variables.reader.getTerminal().writer().println( '' );
					variables.reader.getTerminal().writer().print( arguments.err.stacktrace );
			} else {
				variables.reader.getTerminal().writer().println();
				variables.reader.getTerminal().writer().println( variables.print.whiteText( 'To enable full stack trace, run ' ) & variables.print.boldYellowText( 'config set verboseErrors=true' ) );
			}
		}

		variables.reader.getTerminal().writer().println();
		variables.reader.getTerminal().writer().flush();

		return this;
	}

}
