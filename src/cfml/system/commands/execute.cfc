/**
 * Executes a CFML file and outputs whatever the template outputs using cfoutput or the buffer.
 * 
 * execute myFile.cfm
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false{

	property name="wirebox" inject="wirebox";

	/**
	 * 
	 * @file.hint The file to execute.
	 * 
	 **/
	function run( file="" ){
		// discover file
		if( left( arguments.file, 1 ) != "/" ){
			arguments.file = shell.pwd() & "/" & arguments.file;
		}
		// we use the executor to capture output thread safely
		return wirebox.getInstance( "Executor" ).run( arguments.file );
	}

}