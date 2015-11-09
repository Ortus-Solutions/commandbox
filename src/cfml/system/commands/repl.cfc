/**
 * The REPL (Read-Eval-Print-Loop) command allows you to write and execute a-la-carte CFML code right in 
 * your console. Variables set in will be available on subsequent lines.
 * .
 * {code:bash}
 * repl
 * {code}
 * .
 * By default we surround your code in a 'cfscript' tag, but you can also use the 'script=false'
 * argument to use the REPL console in tag mode.
 * .
 * {code:bash}
 * repl --!script
 * {code}
 * .
 * The REPL has a separate command history for scripts and tags.  Use the up-arrow to look at previous 
 * lines in the history.  The REPLs histories can be managed by the "history" command.
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	// repl history file
	property name="commandHistoryFile"		inject="commandHistoryFile@java";
	property name="REPLScriptHistoryFile"	inject="REPLScriptHistoryFile@java";
	property name="REPLTagHistoryFile"	inject="REPLTagHistoryFile@java";

	// repl parser
	property name="REPLParser"		inject="REPLParser";

	/**
	* Constructor
	*/
	function init(){
		super.init();

		return this;
	}

	/**
	* @input.hint Optional CFML to execute. If provided, the command exits immediatley.
	* @script.hint Run REPL in script or tag mode
	* @directory.hint Directory to start the REPL in (defaults to current working directory).
	**/
	function run( string input,  boolean script=true, string directory='' ){
		
		var quit 	 	= false;
		var results  		= "";
		var executor 		= wirebox.getInstance( "executor" );
		var newHistory 		= arguments.script ? variables.REPLScriptHistoryFile : variables.REPLTagHistoryFile;
		
  	   arguments.directory = fileSystemUtil.resolvePath( arguments.directory );

		// Setup REPL history file
		shell.getReader().setHistory( newHistory );

		if( !structKeyExists( arguments, 'input' ) ) {
			print.cyanLine( "Enter any valid CFML code in the following prompt in order to evaluate it and print out any results (if any)" );
			print.line( "Type 'quit' or 'q' to exit!" ).toConsole();
		}
			
		// Loop until they choose to quit
		while( !quit ){

			// code provided via standard input to process.  Exit after finishing.
			if( structKeyExists( arguments, 'input' ) ) {
				REPLParser.startCommand();
				REPLParser.addCommandLines( arguments.input );
				quit = true;
				
			// Else, collect the code via a prompt
			} else {
	
				// start new command
				REPLParser.startCommand();
	
				do {
					// ask repl
					if ( arrayLen( REPLParser.getCommandLines() ) == 0 ) {
						var command = ask( ( arguments.script ? "CFSCRIPT" : "CFML" ) &  "-REPL: " );
					} else {
						var command = ask( "..." );
	
						// allow ability to break out of adding additional lines
						if ( trim(command) == "exit" ) {
							break;
						}
					}
	
					// add command to our parser
					REPLParser.addCommandLine( command );
	
				} while ( !REPLParser.isCommandComplete() );
	
			}

			// REPL command is complete. get entire command as string
			var cfml = REPLParser.getCommandAsString();
				
			// quitting
			if( listFindNoCase( 'quit,q,exit', cfml ) ){
				quit = true;
			} else {
				
				// evaluate it
				try {

					results = '';

					try {
						// Attempt evaluation
						results = REPLParser.evaluateCommand( executor, arguments.directory );
					} catch (any var e) {
						// execute our command using temp file
						results = executor.runCode( cfml, arguments.script, arguments.directory );
					}

					// print results
					if( !isNull( results ) ){
						// Make sure results is a string
						results = REPLParser.serializeOutput( results );
						print.boldRedLine( results ).toConsole();
					}
					
				} catch( any e ){
					// Log it
					logger.error( '#e.message# #e.detail#' , e.stackTrace );
					error( '#e.message##CR##e.detail#' );
					print.toConsole();
				}
			}
		}
		// flush history out
		newHistory.flush();
		// set back original history 
		shell.getReader().setHistory( commandHistoryFile );
	}


	/**
	* Returns variable type if it can be determined
	**/
	private function determineVariableType( any contents ) {

		var variableType = "";

		try {
			variableType = getMetaData( evaluate( arguments.contents ) ).getName();
		} catch ( any var e ) {
			try {
				variableType = getMetaData( evaluate( arguments.contents ) ).name;
			} catch ( any var e ) {
				// Keep going
			}
		}

		return variableType;
	}

}
