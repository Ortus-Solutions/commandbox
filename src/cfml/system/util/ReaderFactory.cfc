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
		
		var SignalHandler = createObject( "java", "org.jline.terminal.Terminal$SignalHandler" );
		var LineReaderOption = createObject( "java", "org.jline.reader.LineReader$Option" );
		
		var terminal = createObject( "java", "org.jline.terminal.TerminalBuilder" )
			.builder()
        //	.signalHandler( SignalHandler.SIG_IGN )
			.build();
		
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

		return reader;

	}

}
