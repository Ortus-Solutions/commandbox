/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
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
					
		var ansi = createObject( 'java', 'org.fusesource.jansi.Ansi' ).init();
		var AnsiConsole = createObject( 'java', 'org.fusesource.jansi.AnsiConsole' );
		AnsiConsole.systemInstall();
		var ansiErase = createObject( 'java', 'org.fusesource.jansi.Ansi$Erase' );
		// Total space availble to progress bar.  Subtract 5 for good measure since it will wrap if you get too close
		var totalWidth = shell.getTermWidth()-5	;
		
		// TODO: ETA
		var progressBarTemplate = '@@@% [=>] $$$$$$$ / ^^^^^^^  (&&&&&&&&)';
		// Dynamically assign the remaining width to the moving progress bar
		var nonProgressChars = len( progressBarTemplate ) - 1;
		var progressChars = totalWidth - nonProgressChars; 
		
		// Clear the line
		ansi.eraseLine(ansiErase.ALL);
		// Move cursor back to the far left
		ansi.cursorLeft( totalWidth );
		
		// Get the template
		var progressRendered = progressBarTemplate;
		
		// Replace percent
		progressRendered = replace( progressRendered, '@@@', numberFormat( arguments.percent, '___' ) );
		
		// Replace actual progress bar
		var progressSize = int( progressChars * (arguments.percent/100) );
		var barChars = repeatString( '=', progressSize ) & '>' & repeatString( ' ', progressChars-progressSize );
		progressRendered = replace( progressRendered, '=>', barChars );
		 
		// Replace sizes and speed
		progressRendered = replace( progressRendered, '^^^^^^^', formatSize( arguments.totalSizeKB, 7 ) );
		progressRendered = replace( progressRendered, '$$$$$$$', formatSize( arguments.completeSizeKB, 7 ) );
		progressRendered = replace( progressRendered, '&&&&&&&&', formatSize( min( arguments.speedKBps, 99000), 6 ) & 'ps' );
				
		// Add to buffer
 		ansi.a( progressRendered );
 		
 		// If we're done, add a line break
		if( arguments.percent == 100 ) {
			ansi.newline(); 
		}
		 		
 		// Add to console and flush
	 	system.out.print(ansi);
        system.out.flush();
		AnsiConsole.systemUninstall();
        
			
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