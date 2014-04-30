/**
 * Adds a task
 **/
component persistent="false" extends="cli.BaseCommand" aliases="task-add" {

	/** 
	 * @name.hint task name
	 * @interval.hint task interval
	 **/
	function run( required String name, required numeric interval ) {
		return "faux-task-add! Task:#name# Interval:#interval#";
	}

}