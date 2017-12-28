/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* Prints out a progress bar to the screen.
*
*/
component singleton {

	// DI
	property name='system' inject='system@constants';
	property name='shell' inject='shell';

	/**
	* Call me to update the screen.  If another thread outputs to the console in the mean time, it will mess it up.
	* This method assumes it's on a fresh line with the cursor at the far left.
	* Will print a line break if the percent is 100
	* @downloadURL.hint The remote URL to download
	* @destinationFile.hint The local file path to store the downloaded file
	* @statusUDF.hint A closure that will be called once for each full percent of completion. Accepts a struct containing percentage, averageKBPS, totalKB, and downloadedKB
	*/
	public function update(
		required numeric percent,
		required numeric totalSizeKB,
		required numeric completeSizeKB,
		required numeric speedKBps
		) {
		
		var terminal = shell.getReader().getTerminal();
		
		// If Jline uses a "dumb" terminal, the width reports as zero, which throws devide by zero errors.
		// TODO: I might be able to just fake a reasonable width.
		if( terminal.getWidth() == 0 ) {
			return;
		}
		var display = createObject( 'java', 'org.jline.utils.Display' ).init( terminal, false );
		display.resize( terminal.getHeight(), terminal.getWidth() );
		
		// Total space availble to progress bar.  Subtract 5 for good measure since it will wrap if you get too close
		var totalWidth = shell.getTermWidth()-5	;

		// TODO: ETA
		var progressBarTemplate = '@@@% [=>] $$$$$$$ / ^^^^^^^  (&&&&&&&&)';
		// Dynamically assign the remaining width to the moving progress bar
		var nonProgressChars = len( progressBarTemplate ) - 1;
		// Minimum progressbar length is 5.  It will wrap if the user's console is super short, but I'm not sure I care.
		var progressChars = max( totalWidth - nonProgressChars, 5 );

		// Get the template
		var progressRendered = progressBarTemplate;

		// Replace percent
		progressRendered = replace( progressRendered, '@@@', numberFormat( arguments.percent, '___' ) );

		// Replace actual progress bar
		var progressSize = int( progressChars * (arguments.percent/100) );
		var barChars = repeatString( '=', progressSize ) & '>' & repeatString( ' ', max( progressChars-progressSize, 0 ) );
		progressRendered = replace( progressRendered, '=>', barChars );

		// Replace sizes and speed
		progressRendered = replace( progressRendered, '^^^^^^^', formatSize( arguments.totalSizeKB, 7 ) );
		progressRendered = replace( progressRendered, '$$$$$$$', formatSize( arguments.completeSizeKB, 7 ) );
		progressRendered = replace( progressRendered, '&&&&&&&&', formatSize( min( arguments.speedKBps, 99000), 6 ) & 'ps' );
				
		// Add to console and flush
		display.update( [ createObject( 'java', 'org.jline.utils.AttributedString' ).init( progressRendered ) ], 0 );

 		// If we're done, add a line break
		if( arguments.percent == 100 ) {
			shell.printString( chr( 10 ) );
		}
	
	}


	private function formatSize( sizeKB, numberChars ) {
		arguments.sizeKB = round( arguments.sizeKB );

		// Present in MB
		if( arguments.sizeKB >= 1000 ) {

			var sizeMB = arguments.sizeKB/1000;
			var mask = repeatString( '_' , numberChars-4 ) & '.9';
			return numberFormat( sizeMB, mask) & 'MB';

		// Present in KB
		} else {

			var mask = repeatString( '_' , numberChars-2 );
			return numberFormat( arguments.sizeKB, mask) & 'KB';

		}
	}

}
