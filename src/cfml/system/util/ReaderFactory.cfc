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
	property name="CommandCompletor" 		inject="CommandCompletor";
	property name="CommandParser"			inject="CommandParser";
	property name="CommandHighlighter"		inject="CommandHighlighter";
	property name="SignalHandler"			inject="SignalHandler";
	property name="homedir"					inject="homedir@constants";
	property name="commandHistoryFile"		inject="commandHistoryFile@constants";
	property name="REPLScriptHistoryFile"	inject="REPLScriptHistoryFile@constants";
	property name="REPLTagHistoryFile"		inject="REPLTagHistoryFile@constants";
	property name="systemSettings"			inject="SystemSettings";
	property name="configService"			inject="ConfigService";

	/**
	* Build a jline console reader instance
	* @inStream.hint input stream if running externally
	* @outputStream.hint output stream if running externally
	*/
	function getInstance( inStream, outputStream ) {
		var reader = "";

		// Hit this if by adding -clidebug to the box binary.
		// $> box -clidebug
		// Do not be alarmed by errors regarding loading signal handlers from JLine. It just means your terminal doesn't support them.
		if( systemSettings.getSystemProperty( 'cfml.cli.debug', false ) ) {
			// This will make the underlying JLine logger sing...
			var LevelClass = createObject( 'java', 'java.util.logging.Level' );
			var consoleHandler = createObject( 'java', 'java.util.logging.ConsoleHandler' );
			consoleHandler.setLevel( LevelClass.FINE );
			consoleHandler.setFormatter( createObject( 'java', 'java.util.logging.SimpleFormatter' ) );
			var jlineLogger = createObject( 'java', 'java.util.logging.Logger' ).getLogger( 'org.jline' );
	        jlineLogger.setLevel( LevelClass.FINE );
	        jlineLogger.addHandler( consoleHandler );
	        // And this will make the JNA lib chirp
			systemSettings.setSystemProperty( 'jna.debug_load', true );
		}


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
		// https://github.com/fusesource/jansi/blob/2cf446182c823a4c110411b765a1f0367eb8a913/src/main/java/org/fusesource/jansi/internal/JansiLoader.java#L80
		systemSettings.setSystemProperty( 'jansi.tmpdir', JANSI_path );
		// And JNA will pick this up.
		// https://java-native-access.github.io/jna/4.2.1/com/sun/jna/Native.html#getTempDir--
		systemSettings.setSystemProperty( 'jna.tmpdir', JANSI_path );
		
		if( configService.getSetting( 'colorInDumbTerminal', false ) ) {
			systemSettings.setSystemProperty( 'org.jline.terminal.dumb.color', 'true' );
		}

		// Creating static references to these so we can get at nested classes and their properties
		var LineReaderClass = createObject( "java", "org.jline.reader.LineReader" );
		var LineReaderOptionClass = createObject( "java", "org.jline.reader.LineReader$Option" );

		// CFC instances that implements a JLine Java interfaces
		var jCompletor = createDynamicProxy( CommandCompletor , [ 'org.jline.reader.Completer' ] );
		var jParser = createDynamicProxy( CommandParser, [ 'org.jline.reader.Parser' ] );
		var jHighlighter = createDynamicProxy( CommandHighlighter, [ 'org.jline.reader.Highlighter' ] );
		var jSignalHandler = createDynamicProxy( SignalHandler, [ 'org.jline.terminal.Terminal$SignalHandler' ] );

		// Build our terminal instance
		var terminal = createObject( "java", "org.jline.terminal.TerminalBuilder" )
			.builder()
	        .system( true )
	       // .streams( createObject( 'java', 'java.lang.System' ).in, createObject( 'java', 'java.lang.System' ).out )
	        .nativeSignals( true )
	        .signalHandler( jSignalHandler )
	        // This hides the warning when JLine defaults to a dumb terminal on CI builds
	        .dumb( true )
	        .paused( true )
			.build();

		var shellVariables = {
			// The default file for history is set into the shell here though it's used by the DefaultHistory class
			'#LineReaderClass.HISTORY_FILE#' : commandHistoryFile,
			'#LineReaderClass.BLINK_MATCHING_PAREN#' : 0
		};

		if( configService.getSetting( 'tabCompleteInline', false ) ) {
			shellVariables.append( {
				// These color tweaks are to improve the default ugly "pink" color in the optional AUTO_MENU_LIST setting (activated below)
				'#LineReaderClass.COMPLETION_STYLE_LIST_BACKGROUND#' : 'bg:~grey',
				'#LineReaderClass.COMPLETION_STYLE_LIST_DESCRIPTION#' : 'fg:blue,bg:~grey',
				'#LineReaderClass.COMPLETION_STYLE_LIST_STARTING#' : 'inverse,bg:~grey'
			} );
		}

		// Build our reader instance
		reader = createObject( "java", "org.jline.reader.LineReaderBuilder" )
			.builder()
			.terminal( terminal )
			.variables( shellVariables )
        	.completer( jCompletor )
        	.parser( jParser )
        	.highlighter( jHighlighter )
			.build();

		// This lets you hit tab with nothing entered on the prompt and get auto-complete
		reader.unsetOpt( LineReaderOptionClass.INSERT_TAB );
		// This turns off annoying Vim stuff built into JLine
		reader.setOpt( LineReaderOptionClass.DISABLE_EVENT_EXPANSION );
		// Makes auto complete case insensitive
		reader.setOpt( LineReaderOptionClass.CASE_INSENSITIVE );
		// Makes i-search case insensitive (Ctrl-R and Ctrl-S)
		reader.setOpt( LineReaderOptionClass.CASE_INSENSITIVE_SEARCH );
		// Use groups in tab completion
		reader.setOpt( LineReaderOptionClass.GROUP_PERSIST );
		// Activate inline list tab completion
		if( configService.getSetting( 'tabCompleteInline', false ) ) {
			reader.setOpt( LineReaderOptionClass.AUTO_MENU_LIST );
		}


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
																			// Jline 3 escapes backslash
							return instant.now().toEpochMilli() & ':' & line.replace( '\', '\\', 'all' );
						} );
						// Write the new file back out
						fileWrite( historyFile, fileContentsArray.toList( chr( 10 ) ) & chr( 10 ) );
					}
				}

			// If something went really bad, no worries, just nuke the file
			} catch( any var e ) {
				// JLine isn't loaded yet, so I have to use systemOutput() here.
				systemOutput( 'Error updating history file: ' & e.message, 1 );
				fileDelete( historyFile );
			}

		}
	}

}
