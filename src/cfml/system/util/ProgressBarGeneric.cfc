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
	property name='system'   	     inject='system@constants';
	property name='shell'     	    inject='shell';
	property name='print'    	     inject='Print';
	property name='job'           	inject='provider:InteractiveJob';
	property name='ConsolePainter'	inject='provider:ConsolePainter';
	
	property name='active' type='boolean' default='false';
	property name='memento' type='struct';

	function init() {
		variables.attr = createObject( 'java', 'org.jline.utils.AttributedString' );
		setMemento( {} );
	}

	/**
	* Call me to update the screen.
	*/
	public function update(
		required numeric percent,
		currentCount=0,
		totalCount=0
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


	function clear() {
		setActive( false );
		setMemento( {} );
		ConsolePainter.stop();
	}


	function getLines() {

		if( !getActive() ) {
			return [];
		}
		
		var memento = getMemento();
		
		var terminal = shell.getReader().getTerminal();

		var display = createObject( 'java', 'org.jline.utils.Display' ).init( terminal, false );
		display.resize( terminal.getHeight(), terminal.getWidth() );
		var progressRendered = '';

		// Total space available to progress bar.  Subtract 5 for good measure since it will wrap if you get too close
		var totalWidth = shell.getTermWidth()-5;

		if( memento.totalCount > 0 ) {
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
		progressRendered = replace( progressRendered, '@@@%', print.yellow1( numberFormat( memento.percent, '___' ) & '%' ) );

		// Replace actual progress bar
		var progressSize = int( progressChars * (memento.percent/100) );
		var barChars = print.onGreen3( repeatString( ' ', progressSize ) & ' ' ) & repeatString( ' ', max( progressChars-progressSize, 0 ) );
		progressRendered = replace( progressRendered, '=>', barChars );

		if( memento.totalCount > 0 ) {
			progressRendered = replace( progressRendered, '^^^^^^^', print.deepSkyBlue1( numberFormat( memento.totalCount, '_______' ) ) );
			progressRendered = replace( progressRendered, '$$$$$$$', print.deepSkyBlue1( numberFormat( memento.currentCount, '_______' ) ) );
		}

		return [
			attr.fromAnsi( print.Grey66( repeatString( '=', totalWidth ) ) ),
			attr.fromAnsi( progressRendered ),
			attr.fromAnsi( print.Grey66( repeatString( '=', totalWidth ) ) )
		];

	}
	
	function getMemento() {
		return variables.memento.append( {
			percent : 0,
			currentCount : 0,
			totalCount : 0
		}, false )
	}

}
