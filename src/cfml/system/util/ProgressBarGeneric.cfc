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
	property name='system'        inject='system@constants';
	property name='shell'         inject='shell';
	property name='print'         inject='Print';
	property name='job'           inject='provider:InteractiveJob';

	function init() {
		variables.attr = createObject( 'java', 'org.jline.utils.AttributedString' );
	}

	/**
	* Call me to update the screen.  
	*/
	public function update(
		required numeric percent,
		currentCount=0,
		totalCount=0
		) {

		var terminal = shell.getReader().getTerminal();

		// If Jline uses a "dumb" terminal, the width reports as zero, which throws divide by zero errors.
		// TODO: I might be able to just fake a reasonable width.
		if( !shell.isTerminalInteractive() || terminal.getWidth() == 0 ) {
			return;
		}

		var display = createObject( 'java', 'org.jline.utils.Display' ).init( terminal, false );
		display.resize( terminal.getHeight(), terminal.getWidth() );
		var progressRendered = '';

		var lines = [];
		// If there is a currently running job, include its output first so we don't overwrite each other
		if( job.getActive() ) {
			lines = job.getLines();
		}

		// Total space availble to progress bar.  Subtract 5 for good measure since it will wrap if you get too close
		var totalWidth = shell.getTermWidth()-5;

		if( totalCount > 0 ) {
			var progressBarTemplate = '|@@@% |=>| $$$$$$$ / ^^^^^^^ |';			
		} else {
			var progressBarTemplate = '|@@@% |=> |';			
		}
		// Dynamically assign the remaining width to the moving progress bar
		var nonProgressChars = len( progressBarTemplate ) - 1;
		// Minimum progressbar length is 5.  It will wrap if the user's console is super short, but I'm not sure I care.
		var progressChars = max( totalWidth - nonProgressChars, 5 );

		// Get the template
		progressRendered = progressBarTemplate;

		// Replace percent
		progressRendered = replace( progressRendered, '@@@%', print.yellow1( numberFormat( arguments.percent, '___' ) & '%' ) );

		// Replace actual progress bar
		var progressSize = int( progressChars * (arguments.percent/100) );
		var barChars = print.onGreen3( repeatString( ' ', progressSize ) & ' ' ) & repeatString( ' ', max( progressChars-progressSize, 0 ) );
		progressRendered = replace( progressRendered, '=>', barChars );

		if( totalCount > 0 ) {
			progressRendered = replace( progressRendered, '^^^^^^^', print.deepSkyBlue1( numberFormat( arguments.totalCount, '_______' ) ) );
			progressRendered = replace( progressRendered, '$$$$$$$', print.deepSkyBlue1( numberFormat( arguments.currentCount, '_______' ) ) );			
		}
		
		lines.append( [
				attr.fromAnsi( print.Grey66( repeatString( '=', totalWidth ) ) ),
				attr.fromAnsi( progressRendered ),
				attr.fromAnsi( print.Grey66( repeatString( '=', totalWidth ) ) )
			],
			true
		);

		// Add to console and flush
		display.update(
			lines,
			0
		);

 		// If we're done, add a line break
		if( arguments.percent == 100 ) {
			clear();
		}

	}


	function clear() {

		var terminal = shell.getReader().getTerminal();

		if( !shell.isTerminalInteractive() || terminal.getWidth() == 0 ) {
			return;
		}

		var display = createObject( 'java', 'org.jline.utils.Display' ).init( terminal, false );
		display.resize( terminal.getHeight(), terminal.getWidth() );

		var lines = [];
		if( job.getActive() ) {
			lines = job.getLines();
		}

		lines.append( [
				attr.init( repeatString( ' ', terminal.getWidth() ) ),
				attr.init( repeatString( ' ', terminal.getWidth() ) ),
				attr.init( repeatString( ' ', terminal.getWidth() ) )
			],
			true
		);

		display.update(
			lines,
			0
		);
	}

}
