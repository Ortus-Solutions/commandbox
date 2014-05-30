/**
 * Executes a CFML file and outputs whatever the template outputs using cfoutput or the buffer.
 * 
 * execute myFile.cfm
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false{

	/**
	* REPL Console
	**/
	function run(){
		print.line( "Type 'quit' or 'q' to exit!" ).toConsole();

		var quit 	= true;
		var results = "";

		// quit until exist
		while( quit ){
			// ask repl
			var cfml = ask( "CFML-REPL: " );
			// quitting
			if( cfml == "quit" or cfml == "q" ){
				quit = false;
			} else {
				var tempFile = shell.getTempDir() & "/" & createUUID() & ".cfm";
				// evaluate it
				try{
					fileWrite( tempFile, cfml );
					results = wirebox.getInstance( "Executor" ).run( tempFile );
					if( !isNull( results ) ){
						print.redLine( results ).toConsole();
					} else {
						print.boldRedLine( "Null results received!" );
					}
				} catch( any e ){
					error( '#e.message##CR##e.detail#' );
					print.toConsole();
				} finally {
					if( fileExists( tempFile ) ){
						fileDelete( tempFile );
					}
				}
			}
		}

		// exit
		print.boldGreen( "Bye!" );
	}

}