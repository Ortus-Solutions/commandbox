/**
 * Tail the end of a file from the filesystem. Path may be absolute or relative to the current working directory.
 * .
 * {code:bash}
 * tail file.txt
 * {code}
 * Displays the contents of a file to standard CommandBox output according to the number of lines argument.
 * .
 * Use the "lines" param to specify the number of lines to display, or it defaults to 15 lines.
 * .
 * {code:bash}
 * tail file.txt 100
 * {code}
 **/	
component {

	/**
	 * @path file or directory to tail or raw input to process
	 * @lines number of lines to display.
	 * @follow Keep outputting new lines to the file until Ctrl-C is pressed
	 **/
	function run( required path, numeric lines = 15, boolean follow = false ){
		var rawText = false;
		var inputAsArray = listToArray( arguments.path, chr(13) & chr(10) );
		
		// If there is a line break in the input, then it's raw text
		if( inputAsArray.len() > 1 ) {
			var rawText = true;			
		}		
		var filePath = fileSystemUtil.resolvePath( arguments.path );

		if( !fileExists( filePath ) ){
			var rawText = true;
		}
		
		// If we're piping raw text and not a file
		if( rawText ) {
			// Only show the last X lines
			var startIndex = max( inputAsArray.len() - arguments.lines + 1, 1 );
			while( startIndex <= inputAsArray.len() ) {
				print.line( inputAsArray[ startIndex++ ] );
			} 
			
			return;
		}

		variables.file = createObject( "java", "java.io.File" ).init( filePath );
		var startPos = findStartPos();
		var startingLength = 0;
		
		try {
			
			var lineCounter = 0;
			var buffer = [];
			var randomAccessFile = createObject( "java", "java.io.RandomAccessFile" ).init( file, "r" );
			var startingLength = file.length(); 
			variables.position = startingLength;
	
			// move to the end of the file
			randomAccessFile.seek( position );
			// Was the last character a line feed.  
			// Remeber the CRLFs will be coming in reverse order
			var lastLF = false;
	
			while( true ){
	
				// stop looping if we have met our line limit or if end of file
				if ( position < startPos-1 || lineCounter == arguments.lines ) {
					if( buffer.len() ) {
						// Strip any CR or LF from the last (first really) line to eliminate leading line breaks in console output
						buffer[ buffer.len() ] = listChangeDelims( buffer[ buffer.len() ], '', chr(13) & chr( 10 ) );
					}
					break;
				}
	
				var char = randomAccessFile.read();
				
				// Only increment CRs that were preceeded by a LF
				if ( char == 13 && !lastLF ) {
					lineCounter += 1;
				}
				// Check for LF
				if ( char == 10 ) {
					lastLF=true;
					lineCounter += 1;
				} else {	
					lastLF=false;
				}
				if ( char != -1 ) buffer.append( chr( char ) );
	
				// move to the preceding character
				randomAccessFile.seek( position-- );
	
			}
	
			// print our file to console 
			print
				.text( buffer.reverse().toList( "" ) )
				.toConsole();
			
		}
		finally {
			if( isDefined( 'randomAccessFile' ) ) {
				randomAccessFile.close();
			}
		}

		// If we're not following the file, just bail here.
		if( !follow ) { 
			if( buffer.len() ) {
				print.line();
			}
			return;
		}
		
		position = startingLength;
		// This lets the thread know we're still running
		variables.tailRun = true;
		
		try {
			// This thread will keep redrawing the screen while the main thread waits for user input
			threadName = 'tail#createUUID()#';
			thread action="run" name=threadName priority="HIGH" {
				try{
					// Only keep drawing as long as the main thread is active
					while( variables.tailRun ) {
						
							var randomAccessFile = createObject( "java", "java.io.RandomAccessFile" ).init( file, "r" );
							randomAccessFile.seek( position );
							// As long as there is at least one more character in the file
							while( ( var char = randomAccessFile.read() ) > -1 ){					
								// output it
								print
									.text( chr( char ) )
									.toConsole();
														
								randomAccessFile.seek( ++position ); 
							}
							// Close the file every time so we don't keep it open and locked
							randomAccessFile.close();
						
						// Decrease this to speed up the Tail
						sleep( 300 );
					}	
				} catch( any e ) {
					logger.error( e.message & ' ' & e.detail, e.stacktrace );
				}  finally {
					// Clean up after ourselves if anything went wrong
					if( isDefined( 'randomAccessFile' ) ) {
						randomAccessFile.close();
					}
				}
				
			}   // End thread
			
			while( true ) {
				// Wipe out prompt so it doesn't redraw if the user hits enter
				shell.getReader().setPrompt( '' );
				
				// Detect user pressing Ctrl-C
				// Any other characters captured will be ignored
				var line = shell.getReader().readLine();
				if( line == 'q' ) {
					break;
				} else {
					print.boldRedLine( 'To exit press Ctrl-C or "q" followed the enter key.' ).toConsole();
				}
			}

						
		// user wants to exit, they've pressed Ctrl-C 
		} catch ( jline.console.UserInterruptException e ) {
			// make sure the thread exits
			variables.tailRun = false;
			// Wait until the thread finishes its last draw
			thread action="join" name=threadName;
			shell.setPrompt();
		// Something horrible went wrong
		} catch ( any e ) {
			// make sure the thread exits
			variables.tailRun = false;
			// Wait until the thread finishes its last draw
			thread action="join" name=threadName;
			shell.setPrompt();
			rethrow;
		}
		
		// We're done with the Tail, clean up.
		variables.tailRun = false;
		// Wait until the thread finishes its last draw
		thread action="join" name=threadName;
		shell.setPrompt();
		
	}
	
	// Deal with BOM (Byte order mark)
	// TODO: Actually pay attention to the BOM!
	function findStartPos() {
		var randomAccessFile = createObject( "java", "java.io.RandomAccessFile" ).init( file, "r" );
		randomAccessFile.seek( 0 );
		var length = randomAccessFile.length();
		var startPos = 0
		;
		// Will contain the first few bytes of the file represented by an integer
		var peek = '';
		
		// If the file has a least 2 bytes
		if( length > 1 ) {
			// read them
			peek &= randomAccessFile.read();
			randomAccessFile.seek( 1 );
			peek &= randomAccessFile.read();
			// If we found one of the 3 char BOMs
			if( listFindNoCase( '254255,255254', peek ) ) {
				// Start after it
				startPos=2;
			} 
		}
		
		// If the file has a least 3 bytes
		if( length > 2 && ! startPos ) {
			// read them
			randomAccessFile.seek( 2 );
			peek &= randomAccessFile.read();
			// If we found one of the 3 char BOMs
			if( listFindNoCase( '239187191', peek ) ) {
				// Start after it
				startPos=3;
			} 
		}
		// If the file has at least 4 bytes and we didn't find a 3 byte BOM
		if( length > 3 && ! startPos) {
			// Read the fourth byte
			randomAccessFile.seek( 3 );
			peek &= randomAccessFile.read();
			// If we found one of the 4 char BOMs
			if( listFindNoCase( '00254255,25525400', peek ) ) {
				// Start after it
				startPos=4;
			} 
		}
		
		randomAccessFile.close();
		return startPos;
	}
	
}