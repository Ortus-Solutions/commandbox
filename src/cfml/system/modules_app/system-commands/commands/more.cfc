/**
 * Breaks long output up into lines or pages for easy reading.  Pipe the output of another command in and it will break it up for you.
 * Press space to advance one line at a time, Ctrl-c, ESC, or "q" to abort and any other key to advance one page at a time.
 * .
 * {code:bash}
 * forgebox show | more
 * {code}
 **/
component excludeFromHelp=true {

	/**
	* @input The piped input to be displayed or a file path to output.
	* @input.optionsFileComplete true
	 **/
	function run( input='' ) {

		// If the input is a small-ish string with no line breaks, test it to see if it's a file path
		if( len( input ) < 1000 && !find( input, chr(10) ) && !find( input, chr(13) ) && fileExists(  resolvePath( input ) ) ) {
			input = fileRead( resolvePath( input ) );
		}
		// Get terminal height
		var termHeight = shell.getTermHeight()-2;
		// Turn output into an array, breaking on carriage returns
		input = input.replace( chr(13) & chr(10), chr(10), 'all' );
		var content = listToArray( arguments.input, chr(13) & chr(10), true );
		var key= '';
		var i = 0;
		var StopAtLine = termHeight;

		// Loop over content
		while( ++i <= content.len() ) {
			if( i > StopAtLine ) {
				print.toConsole();
				// pause for user input
				key = shell.waitForKey();
				// If space, advance one line
				if( key == ' ' ) {
					StopAtLine++;
				// If ESC or q
				} else if( key == 'escape' || key == 'q' ){
					print.redLine( 'Cancelled...' );
					return;
				// Everything else is one page
				} else {
					// 13 => enter
					StopAtLine += termHeight;
				}
			}
			// print out a line
			print.line( content[ i ] );

		}
	}

}
