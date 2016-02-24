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
	 * @path.hint file or directory to tail
	 * @lines.hint number of lines to display.
	 **/
	function run( required path, numeric lines = 15 ){

		var filePath = fileSystemUtil.resolvePath( arguments.path );

		if( !fileExists( filePath ) ){
			return error( "The file does not exist: #arguments.path#" );
		}

		try {
			
			var lineCounter = 0;
			var buffer = [];
			var file = createObject( "java", "java.io.File" ).init( filePath );
			var randomAccessFile = createObject( "java", "java.io.RandomAccessFile" ).init( file, "r" );
			var position = file.length();
	
			// move to the end of the file
			randomAccessFile.seek( position );
	
			while( true ){
	
				// stop looping if we have met our line limit or if end of file
				if ( position < 0 || lineCounter == arguments.lines ) {
					break;
				}
	
				var char = randomAccessFile.read();
				if ( char == 10 ) lineCounter += 1;
				if ( char != -1 ) buffer.append( chr( char ) );
	
				// move to the preceding character
				randomAccessFile.seek( position-- );
	
			}
	
			// print our file to console 
			print.line( buffer.reverse().toList( "" ) );
			
		}
		finally {
			if( isDefined( 'randomAccessFile' ) ) {
				randomAccessFile.close();
			}
		}
	}
	
}