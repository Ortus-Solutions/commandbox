/**
 * Show the first x lines of a file. Path may be absolute or relative to the current working directory.
 * .
 * {code:bash}
 * head file.txt
 * {code}
 * Displays the contents of a file to standard CommandBox output according to the number of lines argument.
 * .
 * Use the "lines" param to specify the number of lines to display, or it defaults to 15 lines.
 * .
 * {code:bash}
 * head file.txt 100
 * {code}
 **/
 component {
	property name="printUtil"		inject="print";
	property name='ansiFormatter'	inject='AnsiFormatter';

	/**
	 * @path file or directory to tail or raw input to process
	 * @lines number of lines to display.
	 **/
	function run( required path, numeric lines = 15 ){
		var rawText = false;
		var inputAsArray = listToArray( arguments.path, chr(13) & chr(10) );

		// If there is a line break in the input, then it's raw text
		if( inputAsArray.len() > 1 ) {
			var rawText = true;
		}
		var filePath = resolvePath( arguments.path );

		if( !fileExists( filePath ) ){
			var rawText = true;
		}

		// If we're piping raw text and not a file
		if( rawText ) {
			// Only show the first X lines
			var i = 1;
			while( i <= inputAsArray.len() && i <= lines ) {
				print.line( inputAsArray[ i++ ] );
			}

			return;
		}
		
		try {
			var fileObject =  fileObject = fileOpen( filePath );
			// Only show the first X lines
			var i = 1;
			while( i++ <= lines ) {
				print.line( fileReadLine( fileObject ) );
				if( fileIsEOF( fileObject ) ) {
					return;
				}
			}
		} finally {
			if( !isNull( fileObject ) ) {
				fileClose( fileObject );	
			}
		}
		

	}
}
