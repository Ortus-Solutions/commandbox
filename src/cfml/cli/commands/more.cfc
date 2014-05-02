/**
 * This is the more command.  Pipe the output of another command into me and I will break it up for you.
 * Press space to advance one line at a time, Crl-c to abort and any other key to advance one page at a time.
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" excludeFromHelp=true {
	
	/**
	 * @input.hint The piped input to be displayed.
	 **/
	function run( input='' ) {
		// Get terminal height
		var termHeight = shell.getTermHeight()-2;
		// Turn output into an array, breaking on carriage returns
		var content = listToArray( input, CR ); 
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
				if( key == 32 ) {
					StopAtLine++;
				// If Ctrl+c, abort
				} else if( key == 3 ){
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