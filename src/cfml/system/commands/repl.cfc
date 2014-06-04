/**
 * The REPL (Read-Eval-Print-Loop) command allows you to write and execute a-la-carte CFML code right in 
 * your console.  By default we surround your code in a 'cfscript' tag, but you can also use the 'script=false'
 * argument to use the REPL console in tag mode.
 * 
 * Usage: repl
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	property name='tempDirRelative' inject='tempDirRelative';
	property name='tempDir' inject='tempDir';

	/**
	* REPL Console
	**/
	function run( boolean script=true ){
		print.cyanLine( "Enter any valid CFML code in the following prompt in order to evaluate it and print out any results (if any)" );
		print.line( "Type 'quit' or 'q' to exit!" ).toConsole();

		var quit 	= false;
		var results = "";
		var Executor = wirebox.getInstance( "Executor" );

		// Loop until they choose to quit
		while( !quit ){
			// ask repl
			var cfml = ask( ( arguments.script ? "CFSCRIPT" : "CFML" ) &  "-REPL: " );
			// quitting
			if( cfml == "quit" or cfml == "q" ){
				quit = true;
			} else {
				// Temp file to evaluate
				var tempFileName = createUUID() & ".cfm";
				var tempFileAbsolute = tempDir & "/" & tempFileName;
				var tempFileRelative = tempDirRelative & "/" & tempFileName;
				
				// evaluate it
				try{

					// script or not?
					if( arguments.script ){
						cfml = "<cfscript>" & cfml & "</cfscript>";
					}
					// write it out
					fileWrite( tempFileAbsolute, cfml );
					// eval it
					results = Executor.run( tempFileRelative );
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
					if( fileExists( tempFileAbsolute ) ){
						fileDelete( tempFileAbsolute );
					}
				}
			}
		}

		// exit
		print.boldCyanLine( "Bye!" );
	}

}