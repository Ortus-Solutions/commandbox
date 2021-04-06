/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I help update the user's console with progress for a currently executing (foreground)
* job in a nice and tidy way.
*/
component accessors=true singleton {

	processingdirective pageEncoding='UTF-8';

	// An array of possibly-nested job details
	property name='jobs' type='array';
	// Is job currently running
	property name='active' type='boolean';
	// Should we dump the log by default when ending
	property name='dumpLog' type='boolean';
	property name='startTime' type='numeric';
	property name='animation' type='numeric';
	

	// DI
	property name='shell' inject='shell';
	property name='printBuffer' inject='printBuffer';
	property name='print' inject='print';
	property name='ConsolePainter'	inject='provider:ConsolePainter';

	function init() {
		// Static reference to the class so we can create instances later
		aStr = createObject( 'java', 'org.jline.utils.AttributedString' );
		runningAnimationChars = [
			[ ' - ', ' \ ', ' | ', ' / ' ],
			[ '|  ', ' | ', '  |' ],
			[ 'GO!','   ' ],
			[ ' ← ', ' ↖ ', ' ↑ ', ' ↗ ', ' → ', ' ↘ ', ' ↓ ', ' ↙ ' ],
			[ '▏  ', '▎  ', '▍  ', '▌  ', '▋  ', '▊  ', '▉  ', '▉▏ ', '▉▎ ', '▉▍ ', '▉▌ ', '▉▋ ', '▉▊ ', '▉▉ ', '▉▉▏', '▉▉▎', '▉▉▍', '▉▉▌', '▉▉▋', '▉▉▊', '▉▉▉' ],
			[ '▁▁▁', '▂▂▂', '▃▃▃', '▄▄▄', '▅▅▅', '▆▆▆', '▇▇▇', '███', '▇▇▇', '▆▆▆', '▅▅▅', '▄▄▄', '▃▃▃', '▁▁▁' ],
			[ ' ◐ ', ' ◓ ', ' ◑ ', ' ◒ ' ],
			[ ' ⊙⊙', ' ⊙⊙', ' ⊙⊙', ' ◠◠' ],
			[ ' ◢ ', ' ◣ ', ' ◤ ', ' ◥ ' ],
			[ ' ⠁ ', ' ⠂ ', ' ⠄ ', ' ⡀ ', ' ⢀ ', ' ⠠ ', ' ⠐ ', ' ⠈ ' ],
			[ ' ⣾ ', ' ⣽ ', ' ⣻ ', ' ⢿ ', ' ⡿ ', ' ⣟ ', ' ⣯ ', ' ⣷ ' ],
			[ ' ┤ ',  ' ┴ ',  ' ├ ',  ' ┬ ' ],
			[ ' ◐ ',  ' ◓ ',  ' ◑ ',  ' ◒ ' ],
			[ '>  ', ' > ', '  >' ]
		];
		
		setStartTime( 0 );
		setAnimation( 1 )
		return this;
	}

	function onDIComplete() {
		terminal = shell.getReader().getTerminal();
		safeWidth = 80;
		reset();
	}

	/**
	* Reset the internal state of this job
	*/
	function reset() {
		jobs = [];
		setActive( false );
		ConsolePainter.stop();
		return this;
	}

	/**
	* Clear from the screen, but don't reset
	*/
	function clear() {
		setActive( false );
		ConsolePainter.stop();
		return this;
	}

	/**
	* Add a line of logging.  Feel free to use ANSI formatting
	*
	* @line Message to log
	*/
	function addLog( required string line, string color='' ) {
		var termWidth = terminal.getWidth() - ( getCurrentJobDepth() * 4 ) - 3;
		if( termWidth <= 0 ){
			termWidth = 70;
		}

		getCurrentJob()
			.logLines.append(
				// Any log lines with a line break needs to become multiple lines
				toString( line )
					// Break multiple lines into array
					.listToArray( chr( 13 ) & chr( 10 ) )
					// Break lines longer than the current terminal width into multiples
					.reduce( function( result, i ) {
						// Keep breaking off chunks until we're short enough to fit
						while( i.len() > termWidth ) {
							result.append( i.left( termWidth ) );
							i = i.right( -termWidth );
						}
						// Add any remaining.
						if( i.len() ) {
							result.append( i );
						}
						return result;
					}, [] )
					// Apply coloring to all lines if there is a color.
					.map( function( i ) {
						if( color.len() ) {
							return print.text( i, color );
						} else {
							return i;
						}
					} )
				,true
			);
		draw();
		return this;
	}

	/**
	* Convenience method to log a red message
	*
	* @line Message to log
	*/
	function addErrorLog( required string line ) {
		return addLog( line, 'red' );
	}

	/**
	* Convenience method to log a yellow message
	*
	* @line Message to log
	*/
	function addWarnLog( required string line ) {
		return addLog( line, 'yellow' );
	}

	/**
	* Convenience method to log a green message
	*
	* @line Message to log
	*/
	function addSuccessLog( required string line ) {
		return addLog( line, 'green' );
	}

	/**
	* Mark job as completed.  This will print out any final permanent lines and clear the state
	*
	* @dumpLog Dump out all internal log lines permanently to the console
	*/
	function complete( boolean dumpLog=variables.dumpLog ) {
		lock name="job-queue" timeout=20 {
			getCurrentJob().status = 'Complete';
			if( jobs.last().status != 'Running' ) {
				finalizeOutput( dumpLog );
			}
		}
		return this;
	}

	/**
	* Mark job as Failed.  This will print out any final permanent lines and clear the state
	*
	* @dumpLog Dump out all internal log lines permanently to the console
	*/
	function error( string message='', boolean dumpLog=variables.dumpLog ) {
		lock name="job-queue" timeout=20 {
			var currentJob = getCurrentJob();
			currentJob.dumpLog = true;
			currentJob.errorMessage = message;
			currentJob.status = 'Error';
			if( jobs.last().status != 'Running' ) {
				finalizeOutput( dumpLog );
			}
		}
		return this;
	}

	/**
	* Cancel all remaining jobs and mark with error
	*
	* @message Error message to be applied to the current job
	*/
	function errorRemaining( message='' ) {
		while( isActive() ) {
			error( message );
			message = '';
		}
		return this;
	}

	/**
	* Kick off a job.  Clears any previous state and starts drawing
	*
	* @name Name of the job
	*/
	function start( required string name, logSize=5 ) {
		lock name="job-queue" timeout=20 {
			if( !getActive() ) {
				setStartTime( getTickCount() );
				setAnimation( randRange( 1, runningAnimationChars.len() ) )
			}
			setActive( true );
			// If there are currently jobs running...
			if( jobs.len() ) {
				// ... make this a child of he currently active one
				getCurrentJob().children.append( newJob( name, logSize ) );
			} else {
				// ... otherwise just add this as a top level job
				setDumpLog( false );
				jobs.append( newJob( name, logSize ) );
			}
		}
		draw();
		return this;
	}

	/**
	* Outputs final representation of job to console for good
	* Resets the internal state this CFC so all job data is gone
	* and there is no active job.
	*
	* @dumpLog Include all log messages in output regardless of logSize
	*/
	private function finalizeOutput( boolean dumpLog ) {
		printBuffer.clear();
		// Loop over and output each line for good
		getLines( includeAllLogs=dumpLog, finalOutput=true ).each( function( line ) {
			printBuffer.line( line.toAnsi() );
		} );

		// Clear screen
		clear();

		printBuffer.toConsole()

		// Reset internal state
		reset();
	}

	/**
	* Render the information to the console
	*/
	function draw() {
		ConsolePainter.start();
		return this;
	}

	/**
	* Returns array of AttributedString objects that represent this job and its children's current state
	*
	* @job Reference to a job struct so this method can be called recursively
	* @includeAllLogs Ignore logSize and include all log lines
	* @finalOutput True if getting final output at the completion of the job.
	*/
	array function getLines( job, includeAllLogs=false, finalOutput=false ) {
		
		if( !getActive() ) {
			return [];
		}
		
		if( isNull( arguments.job ) ) {
			if( !getJobs().len() ) {
				throw( 'No active job' );
			} else {
				arguments.job = getJobs().first();
			}
		}
		// Display job title
		var lines = [
			aStr.fromAnsi( getJobTitle( job ) )
		];

		// Add error message if it exists
		if( job.errorMessage.len() ) {
			toString( job.errorMessage ).listToArray( chr( 13 ) & chr( 10 ) ).each( function( thisErrorLine) {
				lines.append( aStr.fromAnsi( print.redText( '   | > ' & thisErrorLine ) ) );
			} );
		}

		if( job.status == 'Running' || includeAllLogs || ( finalOutput && job.dumpLog ) ) {
			
			// If we're only showing one line of job logs, don't bother with the ------ dividers
			if( job.logSize > 1 ) {
				lines.append( aStr.fromAnsi( print.text( '   |' & repeatString( '-', min( job.name.len()+15, safeWidth-5 ) ), statusColor( job ) ) ) );
			}
			
			var relevantLogLines = [];
			var thisLogLines = job.logLines;
			var thisLogSize = job.logSize;
			if( includeAllLogs || ( finalOutput && job.dumpLog ) ) {
				thisLogSize = thisLogLines.len();
			}
			// These are the lines that are going to be printed
			if( thisLogLines.len() && thisLogSize > 0 ) {
				relevantLogLines = thisLogLines.slice( max( thisLogLines.len() - thisLogSize + 1, 1 ), min( thisLogLines.len(), thisLogSize ) );
			}
			var i = 0;
			var atLeastOne = false;
			while( ++i <= thisLogSize ) {
				if( i <= relevantLogLines.len() ) {
					lines.append( aStr.fromAnsi( print.text( '   | ', statusColor( job ) ) & relevantLogLines[ i ] ) );
					atLeastOne = true;
				// Uncomment this to force the "log window" to be max height even if there are empty lines at the bottom
				// I don't think I like burning the screen space so right now it just "grows as the log messages come in
				// until it reaches max size at which point it starts scrolling
				} else if( job.name == getCurrentJob().name && isActive() ) {
					//lines.append( aStr.fromAnsi( print.text( '   |  ', statusColor( job ) ) ) );
				}
			}

			// Only print divider if we had at least one log message above
			// also if we're only showing one line of job logs, don't bother with the ------ dividers
			if( atLeastOne && job.logSize > 1 ) {
				lines.append( aStr.fromAnsi( print.text( '   |' & repeatString( '-', min( job.name.len()+15, safeWidth-5 ) ), statusColor( job ) ) ) );
			}

		} // End is job running

		// Add in children
		for( var child in job.children ) {
			lines.append(
				getLines( child, includeAllLogs, finalOutput )
					// Indent our children inside of our own "box"
					.map( function( line ){
						return aStr.fromAnsi( print.text( '   |', statusColor( job ) ) & line.toAnsi() );
					} ),
				true
			);
		}

		return lines;
	}

	/**
	* Returns colored and formatted job title
	*
	* @job Job struct to use
	*/
	private string function getJobTitle( job ) {
		if( job.status == 'Error' ) {
			return print.text( ' × | ' & job.name, statusColor( job ) );
		} else if( job.status == 'complete' ) {
			return print.text( ' √ | ' & job.name, statusColor( job ) );
		} else {
			// Totally ok with finding something cooler than a hyphen here...
			return print.text( '#runningAnimation()#| ' & job.name, statusColor( job ) );
		}
	}
	
	/**
	* Returns a character to aninmate for running jobs
	*
	*/
	function runningAnimation() {
		var thisRunningAnimationChars = runningAnimationChars[ getAnimation() ];
		// How long has this job been running in ms?
		var runningTime = ( getTickCount() ) - getStartTime();
		// Removing the amount of time it takes to completely cycle through the chars an even amount of time, how much is left in the current cycle?
		runningTime = runningTime % ( thisRunningAnimationChars.len() * 500 );		
		// Which char are we on at 500ms per char?
		return thisRunningAnimationChars[ ( runningTime \ 500 ) + 1 ]
	}

	/**
	* Returns name of color for current job status
	*
	* @job Job struct to use
	*/
	private string function statusColor( job ) {
		if( job.status == 'Error' ) {
			return 'red';
		} else if( job.status == 'complete' ) {
			return 'green';
		} else {
			return 'yellow';
		}

	}

	/**
	* Returns empty struct of default job details
	*
	* @name Name of job
	* @logSize Size of the log to display
	*/
	private struct function newJob( name, logSize ) {

		return {
			// The current status of the job
			// Running, Complete, Error
			status : 'Running',
			// Message that goes along with a failed job.
			errorMessage = '',
			// Name of the job
			name : arguments.name ?: '',
			// Array of potentially-ANSI-formatted message from this job
			logLines : [],
			// Number of recent log lines to show on the console
			logSize : arguments.logSize ?: 5,
			// Should log lines for this job only be dumped on completion. Can be overridden by main dumpLog setting
			dumpLog : false,
			// Children jobs
			children : []
		};
	}

	/**
	* Get struct that represents the currently executing job.
	*/
	private struct function getCurrentJob() {
		var pointer = getJobs();
		if( !pointer.len() ) {
			throw( 'No active job' );
		}
		// Declare a closure here for easy recursion
		var getLastChild = function( job ) {
			if( job.children.len() && job.children.last().status=='Running' ) {
				return getLastChild( job.children.last() );
			} else {
				return job;
			}
		}
		// Climb down the rabbit hole until we find the last running job
		return getLastChild( pointer.last() );
	}

	/**
	* Get number that represents the depth of the currently executing job.
	*/
	private numeric function getCurrentJobDepth() {
		var pointer = getJobs();
		var depth = 0;
		if( !pointer.len() ) {
			throw( 'No active job' );
		}
		// Declare a closure here for easy recursion
		var getLastChild = function( job ) {
			depth++;
			if( job.children.len() && job.children.last().status=='Running' ) {
				return getLastChild( job.children.last() );
			} else {
				return job;
			}
		}
		// Climb down the rabbit hole until we find the last running job
		getLastChild( pointer.last() );
		return depth;
	}

	/**
	* Is there an active job?
	*/
	boolean function isActive() {
		return getActive();
	}
}
