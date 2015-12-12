/**
 * Adds a task to be executed on the given interval
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/** 
	 * @name.hint The Task name
	 * @interval.hint The task interval in seconds
	 **/
	function run( required String name, required numeric interval ) {
		print.line( "faux-task-add! Task:#name# Interval:#interval#" );
	}

}