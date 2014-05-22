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

	property name="completor" inject="Completor";
	property name="homedir" inject="homedir";
	
	function getInstance( inStream, printWriter ) {
		var reader = '';
		var system = createObject('java', 'java.lang.System');
		
		// If no print writer was passed in, create one
		if( isNull( arguments.printWriter ) ) {
			
			// Windows
			if( findNoCase( "windows", server.os.name ) ) {
				
				variables.ansiOut = createObject("java","org.fusesource.jansi.AnsiConsole").out;
				
       			// default to Cp850 encoding for Windows
				var encoding = system.getProperty( "jline.WindowsTerminal.output.encoding", "Cp850" );
				var outputStreamWriter = createObject( "java", "java.io.OutputStreamWriter" ).init( variables.ansiOut, encoding );
								
        		arguments.printWriter = createObject("java","java.io.PrintWriter").init( outputStreamWriter );
				var FileDescriptor = createObject( "java", "java.io.FileDescriptor" ).init();
		    	arguments.inStream = createObject( "java", "java.io.FileInputStream" ).init( FileDescriptor.in );
		    	
				reader = createObject( "java", "jline.ConsoleReader" ).init( arguments.inStream, arguments.printWriter );
				
			// Everything other than Windows
			} else {
				
		    	reader = createObject( "java", "jline.ConsoleReader" ).init();

			}
			
		// We were given a print writer to use
		} else {
			
			if( isNull( arguments.inStream ) ) {
		    	var FileDescriptor = createObject( "java", "java.io.FileDescriptor" ).init();
		    	arguments.inStream = createObject( "java", "java.io.FileInputStream" ).init( FileDescriptor.in );
			}
			
	    	reader = createObject( "java", "jline.ConsoleReader" ).init( arguments.inStream, arguments.printWriter );
	    	
		}
		
		// ASSERT: By this time variables.reader is defined
		
		// Create our completer and set it
		var jCompletor = createDynamicProxy( completor , [ 'jline.Completor' ] );
        reader.addCompletor( jCompletor );

		// Create our history file and set it
		var historyFile = createObject( "java", "java.io.File" ).init( homedir & "/.history" );
		var history = createObject( "java", "jline.History" ).init (historyFile );
		reader.setHistory( history );
		
		return reader;

	}
	
}

