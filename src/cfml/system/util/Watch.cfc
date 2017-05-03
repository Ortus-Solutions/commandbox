/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am a watcher that will run code any time files in a directory change.
* I am intended to be used as a transient.  Create a new instance of me for each watch operation.
*/
component accessors=true {
	// DI
	property name='shell'				inject='shell';
	property name='print'				inject='PrintBuffer';
	property name='pathPatternMatcher'	inject='provider:pathPatternMatcher@globber';
	property name='fileSystemUtil'		inject='FileSystem';
	
	// Properties
	property name='changeHash'			type='string';
	property name='watcherRun'			type='boolean';
	property name='pathsToWatch'		type='array';
	property name='changeUDF'			type='function';
	property name='baseDirectory'		type='string';
	property name='delayMS'				type='number';
	
	function onDIComplete() {
		setBaseDirectory( shell.pwd() );
		setDelayMS( 500 );
		// Watch all files recursivley by default
		setPathsToWatch( [ '**' ] );
	}
	
	/**
	* Pass in an array of file globbing paths or any numberof string globbing arguments.
	*/
	public function paths() {
		setPathsToWatch( [] );
		for( var arg in arguments ) {
				var thisPattern = arguments[ arg ];
				pathsToWatch.append( thisPattern, isArray( thisPattern ) );
		}
		return this;
	}
	
	/**
	* Pass in the base directory that the globbing patterns are relative to
	*/
	public function inDirectory( baseDirectory ) {
		setBaseDirectory( arguments.baseDirectory );
		return this;
	}
	
	/**
	* Pass in the number of miliseconds to wait between polls
	*/
	public function withDelay( delayMS ) {
		setDelayMS( arguments.delayMS );
		return this;
	}
	
	/**
	* Pass in a UDF refernce to be executed when the watcher senses a chnage on the file system
	*/
	public function onChange( changeUDF ) {
		setChangeUDF( arguments.changeUDF );
		return this;
	}
	
	/**
	* Call to start the watcher. This method will block until the user ends it with Ctrl+C
	*/
	public function start() {
		
		if( isNull( getChangeUDF() ) ) {
			throw( "No onChange UDF specified.  There's nothing to do!" );	
		}		
		
		setChangeHash( calculateHashes() );
		setWatcherRun( true );
		
		print
			.line()
			.boldRedLine( "Watching Files..." )
			.toConsole();
		
		try {
			var threadName = 'watcher#createUUID()#';
			thread action="run" name="#threadname#" priority="HIGH"{
				try{
					// Run until we exit out of the watcher
					while( getWatcherRun() ){
						// Verify if we have a change
						if( changeDetected() ){
							
							// Fire onChange listener
							var thisChangeUDF = getChangeUDF();
							thisChangeUDF();
		
						} else {
							// Sleep and test again.
							sleep( getDelayMS() );
						}
					}
				} catch( any e ) {
					// Print out error message from exception and continue watching
					print.printRedBoldLine( "An exception has ocurred: #e.message# #e.detail#" )
						.line( e.stacktrace )
						.line()
						.printGreenLine( "Starting watcher again..." )
						.line()
						.toConsole();
				}
			} // end thread
			
			while( true ){
				// Wipe out prompt so it doesn't redraw if the user hits enter
				shell.getReader().setPrompt( '' );	
				// Detect user pressing Ctrl-C
				// Any other characters captured will be ignored
				var line = shell.getReader().readLine();
				if( line == 'q' ) {
					break;
				} else {
					print
						.boldGreenLine( 'To exit press Ctrl-C or "q" followed the enter key.' )
						.toConsole();
				}
			}
			
		
		// user wants to exit, they've pressed Ctrl-C 
		} catch ( jline.console.UserInterruptException e ) {
			
			print
				.printLine( "" )
				.printBoldRedLine( "Stopping..." )
				.toConsole();
			
			// make sure the thread exits
			setWatcherRun( false );
			// Wait until the thread finishes its last draw
			thread action="join" name=threadName;
		// Something horrible went wrong
		} catch ( any e ) {
			// make sure the thread exits
			setWatcherRun( false );
			// Wait until the thread finishes its last draw
			thread action="join" name=threadName;
			rethrow;
		} finally{
			shell.setPrompt();
		}
		
		// make sure the thread exits
		setWatcherRun( false );
		// Wait until the thread finishes
		thread action="join" name=threadName;
		
		return this;
	}


	private function calculateHashes() {
		var globPatterns = getPathsToWatch();
		var thisBaseDir =  fileSystemUtil.resolvePath( getBaseDirectory() );
		
		var fileListing = directoryList(
			thisBaseDir,
			true,
			"query",
			function( path ) {
				// This will normalize the slashes to match
				arguments.path = fileSystemUtil.resolvePath( arguments.path );
								
				// cleanup path so we just get what's inside the base dir
				var thisPath = replacenocase( arguments.path, thisBaseDir, "" );
								
				// Does this path match one of our glob patterns
				return pathPatternMatcher.matchPatterns( globPatterns, thisPath );
			},
			"DateLastModified desc" );
			
		var directoryHash = hash( serializeJSON( fileListing ) );
				
		return directoryHash;
	}
	
	private function changeDetected() {
		var newHash = calculateHashes();
		if( getChangeHash() == newHash ){
			return false;
		} 
		setChangeHash( newHash );
		return true;
	}
	
}