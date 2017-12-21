/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
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
	property name="homedir"				inject="homedir@constants";
	property name="commandHistoryFile"	inject="commandHistoryFile@constants";
	

	/**
	* Build a jline console reader instance
	* @inStream.hint input stream if running externally
	* @outputStream.hint output stream if running externally
	*/
	function getInstance( inStream, outputStream ) {
		var reader = "";
		
		var terminal = createObject( "java", "org.jline.terminal.TerminalBuilder" ).terminal();
		
		var DefaultHistory = createObject( "java", "org.jline.reader.impl.history.DefaultHistory" );
		var LineReaderOption = createObject( "java", "org.jline.reader.LineReader$Option" );
		var LineReader = createObject( "java", "org.jline.reader.LineReader" );
		var jCompletor = createDynamicProxy( completor , [ 'org.jline.reader.Completer' ] );
		
		reader = createObject( "java", "org.jline.reader.LineReaderBuilder" )
			.builder()
			.terminal( terminal )
			.variables( {
				'#LineReader.HISTORY_FILE#' : commandHistoryFile
			} )
        	.completer( jCompletor )
			.build();
			
		
		reader.unsetOpt( LineReaderOption.INSERT_TAB );
				
/*
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

		// Let JLine handle Cntrl-C, and throw a UserInterruptException (instead of dying)
		reader.setHandleUserInterrupt( true );

    	// This turns off special stuff that JLine2 looks for related to exclamation marks
    	reader.setExpandEvents( false );

		// Turn off option to add space to end of completion that messes up stuff like path completion.
		reader.getCompletionHandler().setPrintSpaceAfterFullCompletion( false );

		// Create our completer and set it in the console reader
		var jCompletor = createDynamicProxy( completor , [ 'jline.console.completer.Completer' ] );
        reader.addCompleter( jCompletor );

		// Create our history file and set it in the console reader
		reader.setHistory( commandHistoryFile );
*/
		return reader;

	}

}
