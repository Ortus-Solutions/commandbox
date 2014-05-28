/**
 * Executes a CFML file and outputs whatever the template outputs using cfoutput or the buffer.
 * 
 * execute myFile.cfm
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false{

	// DI
	property name="wirebox" inject="wirebox";

	/**
	 * @file.hint The file to execute
	 **/
	function run( required file ){
		// discover file
		if( left( arguments.file, 1 ) != "/" ){
			arguments.file = shell.pwd() & "/" & arguments.file;
		}
		try{
			// we use the executor to capture output thread safely
			var out = wirebox.getInstance( "Executor" ).run( arguments.file );
		} catch( any e ){
			print.boldGreen( "Error executing #arguments.file#: " );
			return error( '#e.message##CR##e.detail##CR##e.stackTrace#' );
		}

		return ( out ?: "The file '#arguments.file#' executed succesfully!" );
	}

}