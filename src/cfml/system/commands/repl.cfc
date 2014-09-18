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

	/**
	* Constructor
	*/
	function init(){
		super.init();

		// setup tmp include directories
		variables.tmpDirRelative = "/commandbox/system/tmp";
		variables.tmpDirAbsolute = expandPath( "/commandbox/system/tmp" );

		return this;
	}

	/**
	* REPL Console
	* @script.hint Run REPL in script or tag mode
	**/
	function run( boolean script=true ){
		print.cyanLine( "Enter any valid CFML code in the following prompt in order to evaluate it and print out any results (if any)" );
		print.line( "Type 'quit' or 'q' to exit!" ).toConsole();

		var quit 	 		= false;
		var results  		= "";
		var executor 		= wirebox.getInstance( "executor" );
		var newHistory 		= arguments.script ? variables.REPLScriptHistoryFile : variables.REPLTagHistoryFile;

		// Setup REPL history file
		shell.getReader().setHistory( newHistory );
			
		// Loop until they choose to quit
		while( !quit ){
			// ask repl
			var cfml = ask( ( arguments.script ? "CFSCRIPT" : "CFML" ) &  "-REPL: " );
			// quitting
			if( cfml == "quit" or cfml == "q" ){
				quit = true;
			} else {
				// Temp file to evaluate
				var tmpFile = createUUID() & ".cfm";
				var tmpFileAbsolute = variables.tmpDirAbsolute & "/" & tmpFile;
				var tmpFileRelative = variables.tmpDirRelative & "/" & tmpFile;
				
				// evaluate it
				try{

					var cfmlWithoutScript = reReplaceNoCase( cfml, ";", "", "once");

					// script or not?
					if( arguments.script ){
						cfml = "<cfscript>" & cfml & "</cfscript>";
					}
					
					// write it out
					fileWrite( tmpFileAbsolute, cfml );
					
					// eval it
					results = trim( executor.run( tmpFileRelative ) );

					// eval null first
					if( isNull( results ) ){
						print.boldRedLine( "Null results received!" );
					}
					// eval no content
					else if( !len( results ) ) {
						try {
							results = "=> " & evaluate( cfmlWithoutScript );
						} catch (any e) {
							systemoutput( e.message & e.detail );
							// Just move on if there was an error
						}
					} 
					
					//Print content to show.
					print.redLine( results ).toConsole();
					// loop it
				} catch( any e ){
					error( '#e.message##CR##e.detail#' );
					print.toConsole();
				} finally {
					// cleanup
					if( fileExists( tmpFileAbsolute ) ){
						fileDelete( tmpFileAbsolute );
					}
				}
			}
		}
		// flush history out
		newHistory.flush();
		// set back original history
		shell.getReader().setHistory( commandHistoryFile );
		// exit
		print.boldCyanLine( "Bye!" );
	}

}