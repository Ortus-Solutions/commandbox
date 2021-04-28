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
component singleton accessors=true {

	// DI
	property name='system'			inject='system@constants';
	property name='shell'			inject='shell';
	property name='print'			inject='Print';
	property name='job'        		inject='provider:InteractiveJob';
	property name='ConsolePainter'	inject='provider:ConsolePainter';
	
	property name='active' type='boolean' default='false';
	property name='memento' type='struct';

	function init() {
		variables.attr = createObject( 'java', 'org.jline.utils.AttributedString' );
		setMemento( {} );
	}

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

		// If we're done, clear ourselves
		if( arguments.percent == 100 ) {
			clear();
			return;
		}
		
		setActive( true );
		setMemento( arguments );
		ConsolePainter.start();
	}
	
	function getLines() {

		if( !getActive() ) {
			return [];
		}
		
		var memento = getMemento();
		var terminal = shell.getReader().getTerminal();

		var progressRendered = '';

		var lines = [];

		// We don't know the total size (all we can show is the amount downloaded thus far)
		if( memento.totalSizeKB == -1 ) {

			var progressBarTemplate = 'Downloading: $$$$$$$ (&&&&&&&&)';
			progressRendered = replace( progressBarTemplate, '$$$$$$$', formatSize( memento.completeSizeKB, 7 ) );
			progressRendered = replace( progressRendered, '&&&&&&&&', formatSize( min( memento.speedKBps, 99000), 6 ) & 'ps' );


			lines.append( [
					attr.fromAnsi( progressRendered ),
				],
				true
			);

		// We do know the total size (show percentages)
		} else {

			// Total space available to progress bar.  Subtract 5 for good measure since it will wrap if you get too close
			var totalWidth = shell.getTermWidth()-5;

			var progressBarTemplate = '|@@@% |=>| $$$$$$$ / ^^^^^^^ | &&&&&&&& |';

			if( memento.speedKBps > 0 ) {
				var remainingKB = memento.totalSizeKB - memento.completeSizeKB;
				var remainingSec = round( remainingKB / memento.speedKBps );
				progressBarTemplate &= ' ETA: #formatExecTime( remainingSec )# |';
			} else {
				progressBarTemplate &= ' ETA: -- |';
			}

			// Dynamically assign the remaining width to the moving progress bar
			var nonProgressChars = len( progressBarTemplate ) - 1;
			// Minimum progressbar length is 5.  It will wrap if the user's console is super short, but I'm not sure I care.
			var progressChars = max( totalWidth - nonProgressChars, 5 );

			// Get the template
			progressRendered = progressBarTemplate;

			// Replace percent
			progressRendered = replace( progressRendered, '@@@%', print.yellow1( numberFormat( memento.percent, '___' ) & '%' ) );

			// Replace actual progress bar
			var progressSize = int( progressChars * (memento.percent/100) );
			var barChars = print.onGreen3( repeatString( ' ', progressSize ) & ' ' ) & repeatString( ' ', max( progressChars-progressSize, 0 ) );
			progressRendered = replace( progressRendered, '=>', barChars );

			// Replace sizes and speed
			progressRendered = replace( progressRendered, '^^^^^^^', print.deepSkyBlue1( formatSize( memento.totalSizeKB, 7 ) ) );
			progressRendered = replace( progressRendered, '$$$$$$$', print.deepSkyBlue1( formatSize( memento.completeSizeKB, 7 ) ) );
			progressRendered = replace( progressRendered, '&&&&&&&&', print.orangeRed1( formatSize( min( memento.speedKBps, 99000), 6 ) & 'ps' ) );

			lines.append( [
					attr.fromAnsi( print.Grey66( repeatString( '=', totalWidth ) ) ),
					attr.fromAnsi( progressRendered ),
					attr.fromAnsi( print.Grey66( repeatString( '=', totalWidth ) ) )
				],
				true
			);
		}

		return lines;
	}

	function clear() {
		setActive( false );
		setMemento( {} );
		ConsolePainter.stop();
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

	function formatExecTime( sec ) {

		if( sec < 1 ) {
			sec = 1;
		}

		var hr = 0;
		var min = 0;

		while( sec >= 60 ) {

		  sec = sec - 60
		  min = min + 1;
		  if (sec == 60) sec = 0;
		  if (min >= 60) hr = hr + 1;
		  if (min == 60) min = 0;

		}
		var outputTime = [];
		// Output hours if they exist
		if( hr ) outputTime.append( '#hr#hr' );
		// Output minutes if they exist or if we printed  hours  (2hr 0min) or (3d 0hr 0min)
		if( min || hr ) outputTime.append( '#min#min' );
		// Ignore seconds for times over an hour. (2hr 31min) Print zero seconds if there were minutes (3min 0sec)
		if( ( sec || min ) && !hr ) outputTime.append( '#sec#sec' );

		return outputTime.toList( ' ' );
	}

}
