/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* Handles timed redraws of the console for downloadable progress bars, generic progress bars, and interactive jobs
*
*/
component singleton accessors=true {
	// DI
	property name='wirebox'				inject='wirebox';
	property name="progressBarGeneric"	inject="progressBarGeneric";
	property name="progressBar"			inject="progressBar";
	property name="job"					inject="InteractiveJob";
	property name='shell'				inject='shell';
	property name='SystemSettings'		inject='SystemSettings';
	property name='multiSelect';

	property name='active' type='boolean' default='false';
	property name='taskScheduler';
	property name='future';

	function onDIComplete() {
		variables.attr = createObject( 'java', 'org.jline.utils.AttributedString' );
		setTaskScheduler( wirebox.getTaskScheduler() );
		terminal = shell.getReader().getTerminal();
		display = createObject( 'java', 'org.jline.utils.Display' ).init( terminal, false );
	}

	/**
	* Starts up the scheduled painting thread if not already started
	*
	*/
	function start() {

		// If we have a dumb terminal or are running inside a CI server, skip the screen redraws all together.
		if( systemsettings.getSystemSetting( 'box_currentCommandPiped', false ) || !shell.isTerminalInteractive() || terminal.getWidth() == 0 ) {
			return;
		}

		if( !getActive() ) {
			lock timeout="20" name="ConsolePainter" type="exclusive" {
				if( !getActive() ) {
					setFuture(
						getTaskScheduler().newSchedule( ()=>paint() )
					        .every( 200 )
					        .start()
					);

					setActive( true );
				}
			}
		}
	}

	/**
	* Stops the scheduled painting thread if no jobs or progress bars are active and it's not already stopped
	*
	*/
	function stop() {

		// Check if all jobs and progress bars are finished
		if(
			progressBarGeneric.getActive()
			|| progressBar.getActive()
			|| job.getActive()
			|| ( !isNull( multiSelect ) && multiSelect.getActive() )
		) {
			return;
		}

		if( getActive() ) {
			lock timeout="20" name="ConsolePainter" type="exclusive" {
				if( getActive() ) {
					getFuture().cancel();
					try {
						getFuture().get();
					} catch(any e) {
						// Throws CancellationException
					}
					setActive( false );
					clear();
				}
			}
		}


	}

	/**
	* Stops up the scheduled painting thread and forces any active jobs to error and any active progress bars to clear
	*
	*/
	function forceStop( string message='' ) {
		job.errorRemaining( message );
		progressBarGeneric.clear();
		progressBar.clear();
		stop();
	}

	/**
	* Draw the lines to the console
	*
	*/
	function paint() {
		try {
			var height = max( terminal.getHeight()-2, 0 );
			display.resize( terminal.getHeight(), terminal.getWidth() );

			var lines = [];
			cursorPosInt = 0;

			// Future enhancement: allow paintable things to be registered with the ConsolePainter intead of these hard coded references.
			lines.append( job.getLines(), true );
			lines.append( progressBar.getLines(), true );
			lines.append( progressBarGeneric.getLines(), true );
			if( !isNull( multiSelect ) && multiSelect.getActive() ) {
				var cursorPos = multiSelect.getCursorPosition();
				cursorPosInt = terminal.getSize().cursorPos( cursorPos.row+lines.len(), cursorPos.col );
				lines.append( multiSelect.getLines(), true );
			}
			// /Future enhancement

			lines.append( attr.init( repeatString( ' ', terminal.getWidth() ) ) );

			// Trim to terminal height so the screen doesn't go all jumpy
			// If there is more output than screen, the user just doesn't get to see the rest
			if( lines.len() > height ) {
				lines = lines.slice( lines.len()-height, lines.len()-(lines.len()-height) );
			}

			// Add to console and flush
			display.update(
				lines,
				cursorPosInt
			);

		} catch( any e ) {
			if( !(e.type contains 'interrupt') ) {
				systemoutput( e.message & ' ' & e.detail, 1 );
				systemoutput( "#e.tagContext[1].template#: line #e.tagContext[1].line#", 1 );
				rethrow;
		 	}
		}
	}

	/**
	* Clear the console
	*/
	function clear() {
		display.resize( terminal.getHeight(), terminal.getWidth() );
		sleep(100)
		display.update(
			[ attr.init( ' ' ) ,attr.init( ' ' ) ,attr.init( ' ' ) ,attr.init( ' ' ) ],
			0
		);

	}
}