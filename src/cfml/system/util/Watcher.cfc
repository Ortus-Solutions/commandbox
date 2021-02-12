/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am a watcher that will run code any time files in a directory change.
* I am intended to be used as a transient.  Create a new instance of me for each watch operation.
*
*
*	getInstance( 'watcher' )
*		.paths( '**.cfc' )
*		.inDirectory( getCWD() )
*		.onChange( function( changeData ) {
			// changeData.added
			// changeData.removed
			// changeData.changed
*			command( 'testbox run' )
*				.run();
*		} )
*		.start();
*/
component accessors=true {
	// DI
	property name='shell'				inject='shell';
	property name='print'				inject='PrintBuffer';
	property name='pathPatternMatcher'	inject='provider:pathPatternMatcher@globber';
	property name='fileSystemUtil'		inject='FileSystem';
	property name='fileSeparator'		inject='fileSeparator@constants';

	// Properties
	property name='changeHash'			type='string';
	property name='fileIndex'			type='struct';
	property name='changeData'			type='struct';
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
	* Pass in a UDF reference to be executed when the watcher senses a chnage on the file system
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
							thisChangeUDF( getChangeData() );

							// In case the change UDF modified the file system,
							// reset our hashes so we don't end up with endless firing
							setChangeHash( calculateHashes() );

						} else {
							// Sleep and test again.
							sleep( getDelayMS() );
						}
					}
				// Handle "expected" exceptions from commands
				} catch( commandException e ) {
					shell.printError( { message : e.message, detail: e.detail } );

					print
						.line()
						.printGreenLine( "Starting watcher again..." )
						.line()
						.toConsole();

					// Fire the watcher up again.
					retry;
				// If the thread has been interrupted
				} catch( java.lang.InterruptedException e ) {
					// There's nothign to do here.  Just exit the thread!
				} catch( java.lang.ThreadDeath e ) {
					// There's nothign to do here.  Just exit the thread!
				} catch( any e ) {
					shell.printError( e );

					print
						.line()
						.printGreenLine( "Starting watcher again..." )
						.line()
						.toConsole();

					// Fire the watcher up again.
					retry;
				}
			} // end thread

			while( true ){

				// Need to start reading the input stream or we can't detect Ctrl-C on Windows
				var terminal = shell.getReader().getTerminal();
				if( terminal.paused() ) {
						terminal.resume();
				}

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

		// user wants to exit this command, they've pressed Ctrl-C
		} catch ( org.jline.reader.UserInterruptException e ) {

			print
				.printLine( "" )
				.printBoldRedLine( "Stopping..." )
				.toConsole();

			// make sure the thread exits
			setWatcherRun( false );
			// Wait until the thread finishes its last draw
			thread action="terminate" name=threadName;

		// user wants to exit the shell, they've pressed Ctrl-D
		} catch ( org.jline.reader.EndOfFileException e ) {

			print
				.printLine( "" )
				.printBoldRedLine( "Stopping and exiting shell..." )
				.toConsole();

			// make sure the thread exits
			setWatcherRun( false );
			// Wait until the thread finishes its last draw
			thread action="terminate" name=threadName;
			shell.setKeepRunning( false );

		// Something horrible went wrong
		} catch ( any e ) {
			// make sure the thread exits
			setWatcherRun( false );
			// Wait until the thread finishes its last draw
			thread action="terminate" name=threadName;
			rethrow;
		} finally{
			shell.setPrompt();
		}

		// make sure the thread exits
		setWatcherRun( false );
		// Wait until the thread finishes
		thread action="terminate" name=threadName;

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

			var fileIndex = {};
			for(file in fileListing){
				var thisPath = replacenocase( file.directory & fileSeparator & file.name, thisBaseDir, "" );
				fileIndex[thisPath] = file.DATELASTMODIFIED;
			}

			setFileIndex( fileIndex );

		var directoryHash = hash( serializeJSON( fileListing ) );

		return directoryHash;
	}

	private function changeDetected() {
		var previousWatchList = getFileIndex();
		var newHash = calculateHashes();

		if( getChangeHash() == newHash ){
			return false;
		}
		var currentWatchList = getFileIndex();

		var changes = { 'added':[], 'removed':[], 'changed':[] };

		//loop over new array and look for changes and adds
		currentWatchList.each( function( filePath, fileDate ){
			//if found check for date change, else new file
			if(structKeyExists( previousWatchList, filePath )){
				if( previousWatchList[ filePath ] != fileDate ){ changes.changed.append( filePath ); }
			} else {
				changes.added.append( filePath );
			}
		})

		//look for deleted files that no longer exist in the list
		previousWatchList.each( function( filePath, fileDate ){
			if( !structKeyExists( currentWatchList, filePath ) ){ changes.removed.append( filePath ); }
		})

		setChangeData( changes );
		setChangeHash( newHash );
		return true;
	}

}
