/**
 * The REPL (Read-Eval-Print-Loop) command allows you to write and execute a-la-carte CFML code right in 
 * your console.  By default we surround your code in a 'cfscript' tag, but you can also use the 'script=false'
 * argument to use the REPL console in tag mode.
 * 
 * Usage: repl
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

					// script or not?
					if( arguments.script ){
						cfml = "<cfscript>" & cfml & "</cfscript>";
					}
					// write it out
					fileWrite( tmpFileAbsolute, cfml );
					// eval it
					results = executor.run( tmpFileRelative );
					// print results
					if( !isNull( results ) ){
						print.redLine( results ).toConsole();
					} else {
						print.boldRedLine( "Null results received!" );
					}
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