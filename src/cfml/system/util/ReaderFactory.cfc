/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
* 
* The logic to create the console reader was hairy enough I've refactored it out into its own file.
*
*/
component singleton{

	// DI
	property name="completor" 			inject="Completor";
	property name="homedir"				inject="homedir";
	property name="commandHistoryFile"	inject="commandHistoryFile@java";	
	
	/**
	* Build a jline console reader instance
	* @inStream.hint input stream if running externally
	* @outputStream.hint output stream if running externally
	*/
	function getInstance( inStream, outputStream ) {
		var reader = "";
		
		// If no print writer was passed in, create one
		if( isNull( arguments.outputStream ) ) {
			// create the jline console reader
			reader = createObject( "java", "jline.console.ConsoleReader" ).init();
		// We were given a print writer to use
		} else {
			
			if( isNull( arguments.inStream ) ) {
		    	var FileDescriptor = createObject( "java", "java.io.FileDescriptor" ).init();
		    	arguments.inStream = createObject( "java", "java.io.FileInputStream" ).init( FileDescriptor.in );
			}
			
	    	reader = createObject( "java", "jline.console.ConsoleReader" ).init( arguments.inStream, arguments.outputStream );
		}
		
		// Create our completer and set it in the console reader
		var jCompletor = createDynamicProxy( completor , [ 'jline.console.completer.Completer' ] );
        reader.addCompleter( jCompletor );

		// Create our history file and set it in the console reader
		reader.setHistory( commandHistoryFile );
		
		return reader;

	}
	
}