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
	property name="JLineParser"			inject="JLineParser";
	property name="homedir"				inject="homedir@constants";
	property name="commandHistoryFile"	inject="commandHistoryFile@constants";
	

	/**
	* Build a jline console reader instance
	* @inStream.hint input stream if running externally
	* @outputStream.hint output stream if running externally
	*/
	function getInstance( inStream, outputStream ) {
		var reader = "";
		
		// Creating static references to these so we can get at nested classes and their properties
		var LineReaderOption = createObject( "java", "org.jline.reader.LineReader$Option" );
		var LineReader = createObject( "java", "org.jline.reader.LineReader" );
		var SignalHandler = createObject( "java", "org.jline.terminal.Terminal$SignalHandler" );
		var LineReaderOption = createObject( "java", "org.jline.reader.LineReader$Option" );
		
		// A CFC instance of our completor that implements a JLine Java interface
		var jCompletor = createDynamicProxy( completor , [ 'org.jline.reader.Completer' ] );
		var jParser = createDynamicProxy( JLineParser, [ 'org.jline.reader.Parser' ] );
				
		// This prevents JLine's inbuilt parsing from swallowing things like backslashes.  CommandBox has its own parser.
		//var parser = createObject( "java", "org.jline.reader.impl.DefaultParser" );
		//parser.setEscapeChars( javaCast( 'null', '' ) );
		
		// Build our terminal instance
		var terminal = createObject( "java", "org.jline.terminal.TerminalBuilder" )
			.builder()
			.build();
		
		// Build our reader instance
		reader = createObject( "java", "org.jline.reader.LineReaderBuilder" )
			.builder()
			.terminal( terminal )
			.variables( {
				// The default file for history is set into the shell here though it's used by the DefaultHistory class
				'#LineReader.HISTORY_FILE#' : commandHistoryFile
			} )
        	.completer( jCompletor )
        	.parser( jParser )
			.build();
			
		// This lets you hit tab with nothing entered on the prompt and get auto-complete
		reader.unsetOpt( LineReaderOption.INSERT_TAB );
		// This turns off annoying Vim stuff built into JLine
		reader.setOpt( LineReaderOption.DISABLE_EVENT_EXPANSION );
		// This is _supposed_ to make auto complete case insensitive but it doesn't seem to work
		reader.setOpt( LineReaderOption.CASE_INSENSITIVE );

		return reader;

	}

}
