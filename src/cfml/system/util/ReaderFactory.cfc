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
component singleton {

	// DI
	property name="completor" 	inject="Completor";
	property name="homedir" 	inject="homedir";
	property name="historyFile"	inject="historyFile";	
	
	/**
	* Build a jline console reader instance
	*/
	function getInstance( inStream, printWriter ) {
		var reader = "";
		
		// If no print writer was passed in, create one
		if( isNull( arguments.printWriter ) ) {
			// create the jline console reader
			reader = createObject( "java", "jline.console.ConsoleReader" ).init();
		// We were given a print writer to use
		} else {
			
			if( isNull( arguments.inStream ) ) {
		    	var FileDescriptor = createObject( "java", "java.io.FileDescriptor" ).init();
		    	arguments.inStream = createObject( "java", "java.io.FileInputStream" ).init( FileDescriptor.in );
			}
			
	    	reader = createObject( "java", "jline.console.ConsoleReader" ).init( arguments.inStream, arguments.printWriter );
	    	
		}
		
		// Create our completer and set it
		var jCompletor = createDynamicProxy( completor , [ 'jline.console.completer.Completer' ] );
        reader.addCompleter( jCompletor );

		// Create our history file and set it
		var oHistoryFile = createObject( "java", "java.io.File" ).init( historyFile );
		var history = createObject( "java", "jline.console.history.FileHistory" ).init ( oHistoryFile );
		reader.setHistory( history );
		
		return reader;

	}
	
}