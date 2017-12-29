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
	property name="JLineHighlighter"	inject="JLineHighlighter";
	property name="JLineSignalHandler"	inject="JLineSignalHandler";
	property name="homedir"				inject="homedir@constants";
	property name="commandHistoryFile"	inject="commandHistoryFile@constants";
	property name="REPLScriptHistoryFile"	inject="REPLScriptHistoryFile@constants";
	property name="REPLTagHistoryFile"	inject="REPLTagHistoryFile@constants";
	property name="systemSettings"		inject="SystemSettings";

	/**
	* Build a jline console reader instance
	* @inStream.hint input stream if running externally
	* @outputStream.hint output stream if running externally
	*/
	function getInstance( inStream, outputStream ) {
		var reader = "";
		
		// Before we laod JLine, auto-convert any legacy history files.  JLine isn't smart enough to use them
		upgradeHistoryFile( commandHistoryFile );
		upgradeHistoryFile( REPLScriptHistoryFile );
		upgradeHistoryFile( REPLTagHistoryFile );
		
		// Work around for lockdown STIGs on govt machines.
		// By default JANSI tries to write files into a locked down folder under appData
		var JANSI_path = expandPath( '/commandbox-home/lib/jansi' );
		if( !directoryExists( JANSI_path ) ){
			directoryCreate( JANSI_path );
		}
		// The JANSI lib will pick this up and use it
		systemSettings.setSystemProperty( 'library.jansi.path', JANSI_path );
		
		// Creating static references to these so we can get at nested classes and their properties
		var LineReader = createObject( "java", "org.jline.reader.LineReader" );
		var SignalHandler = createObject( "java", "org.jline.terminal.Terminal$SignalHandler" );
		var LineReaderOption = createObject( "java", "org.jline.reader.LineReader$Option" );
		
		// CFC instances that implements a JLine Java interfaces
		var jCompletor = createDynamicProxy( completor , [ 'org.jline.reader.Completer' ] );
		var jParser = createDynamicProxy( JLineParser, [ 'org.jline.reader.Parser' ] );
		var jHighlighter = createDynamicProxy( JLineHighlighter, [ 'org.jline.reader.Highlighter' ] );
		var jSignalHandler = createDynamicProxy( JLineSignalHandler, [ 'org.jline.terminal.Terminal$SignalHandler' ] );
		
		// Build our terminal instance
		var terminal = createObject( "java", "org.jline.terminal.TerminalBuilder" )
			.builder()
	        .system( true )
	        .nativeSignals( true )
	        .signalHandler( jSignalHandler )
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
        	.highlighter( jHighlighter )
			.build();
			
		// This lets you hit tab with nothing entered on the prompt and get auto-complete
		reader.unsetOpt( LineReaderOption.INSERT_TAB );
		// This turns off annoying Vim stuff built into JLine
		reader.setOpt( LineReaderOption.DISABLE_EVENT_EXPANSION );
		// This is _supposed_ to make auto complete case insensitive but it doesn't seem to work
		reader.setOpt( LineReaderOption.CASE_INSENSITIVE );

		return reader;

	}
	
	private function upgradeHistoryFile( required string historyFile ) {
		
		if( fileExists( historyFile ) ) {
			
			try {
				
				var fileContents = fileRead( historyFile );
				if( fileContents.len() ) {
					// break on line breaks into array 
					var fileContentsArray = fileContents.listToArray( chr( 13 ) & chr( 10 ) );
					// Test the first line to see if it isn't in format of
					// 1513970736912:cat myFile.txt
					if( fileContentsArray.first().listLen( ':' ) == 1 ) {
						var instant = createObject( 'java', 'java.time.Instant' );
						// Add epoch milis and a colon to each line
						fileContentsArray = fileContentsArray.map( function( line ) {
							return instant.now().toEpochMilli() & ':' & line;
						} );
						// Write the new file back out
						fileWrite( historyFile, fileContentsArray.toList( chr( 10 ) ) );
					}
				}
			
			// If something went really bad, no worries, just nuke the file
			} catch( any var e ) {
				systemOutput( 'Error updating history file: ' & e.message, 1 );
				fileDelete( historyFile );
			}
			
		}
	}

}
