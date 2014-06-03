/**
 * The REPL (Read-Eval-Print-Loop) command allows you to write and execute a-la-carte CFML code right in 
 * your console.  By default we surround your code in a 'cfscript' tag, but you can also use the 'script=false'
 * argument to use the REPL console in tag mode.
 * 
 * Usage: repl
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false{

	/**
	* REPL Console
	**/
	function run( boolean script=true ){
		print.cyanLine( "Enter any valid CFML code in the following prompt in order to evaluate it and print out any results (if any)" );
		print.line( "Type 'quit' or 'q' to exit!" ).toConsole();

		var quit 	= true;
		var results = "";

		// quit until exist
		while( quit ){
			// ask repl
			var cfml = ask( ( arguments.script ? "CFSCRIPT" : "CFML" ) &  "-REPL: " );
			// quitting
			if( cfml == "quit" or cfml == "q" ){
				quit = false;
			} else {
				var tempFile = shell.getTempDir() & "/" & createUUID() & ".cfm";
				// evaluate it
				try{

					// script or not?
					if( arguments.script ){
						cfml = "<cfscript>" & cfml & "</cfscript>";
					}
					// write it out
					fileWrite( tempFile, cfml );
					// eval it
					results = wirebox.getInstance( "Executor" ).run( tempFile );
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
					if( fileExists( tempFile ) ){
						fileDelete( tempFile );
					}
				}
			}
		}

		// exit
		print.boldCyanLine( "Bye!" );
	}

}