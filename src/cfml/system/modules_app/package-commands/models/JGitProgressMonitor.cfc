/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood
*
* Prints out a progress bar to the screen.
*
*/
component {
	property name="shell"	inject="shell";
	property name="wirebox"	inject="wirebox";
	
	function init() {
		// Unknown amount of work
		variables.UNKNOWN = createOBject( 'java', 'org.eclipse.jgit.lib.ProgressMonitor' ).UNKNOWN;
		// Last time interrupt was checked.
		variables.lastInterrupt = 0;
	}
	
	function onDIComplete() {
		variables.job = wirebox.getInstance( 'interactiveJob' );
		variables.progressBarGeneric = wirebox.getInstance( 'progressBarGeneric' );
		reset();
	}

	/**
	* The progress monitor is starting.
	*/
	function start( numeric totalTasks ) {
		// Really nothing to do here and the totalTasks seems to be a lie anyway.  Good job, JGit.
	}
	
	/**
	* A new task is starting
	*/
	function beginTask( string title, numeric totalWork ) {
		// Sometimes endTask() never gets called when total work is unknown so always reset just in case when starting a new task
		reset();
		
		if( totalWork == UNKNOWN ) {
			job.addLog( '#title#'  );
		} else {
			job.addLog( '#title# (#totalWork#)'  );
			currentTotal = totalWork;
			progressBarGeneric.update( 0 );
		}
	}

	/**
	* Some progress has happened on the current task
	*/
	function update( numeric completed ) {
		if( currentTotal > 0 ) {
			currentCount += completed;
			thisPerc = int( 100 * (currentCount / currentTotal ) );
			// Update every 1 percent to avoid extra redraws
			if( thisPerc > lastPercent ) {
				progressBarGeneric.update( thisPerc, currentCount, currentTotal );
				lastPercent = thisPerc;	
			}
		}
	}

	/**
	* The current task is done
	*/
	function endTask() {
		reset();
	}

	/**
	* Check and see if the user has pressed Ctrl-C to cancel
	*/
	boolean function isCancelled() {
		var tick = getTickcount();
		// Only do this check once a second or it really starts to drag stuff down
		if( tick - lastInterrupt < 1000 ) {
			return false;
		}
		// Defer to the shell to check if the user has hit Ctrl-C
		shell.checkInterrupted();
		lastInterrupt = tick;
		return false;
	}

	/**
	* Reset internal states of tasks counters and clear any progress bars from the screen
	*/
	private function reset() {
		currentTotal = 0;
		currentCount = 0;
		lastPercent = 0;
		progressBarGeneric.clear();
	}	
	
}