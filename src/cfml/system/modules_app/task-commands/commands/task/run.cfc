/**
 * Run a task.  By default this will look for a file called "task.cfc" in the current directory and invoke it's run() method.
 *
 * {code}
 * task run
 * {code}
 *
 * Override the file name and/or method name with the taskFile and target parameters. The .cfc is optional.
 *
 * {code}
 * task run build.cfc createZips
 * {code}
 *
 * To pass parameters to your task, include additional positional parameters or named parameters starting with a colon (:).
 * Theses parameters will appear directly in the arguments scope of the task.
 *
 * {code}
 * task run build.cfc createZips value1 value2
 * task run :param1=value1 :param2=value2
 * {code}
 *
 **/
component {
	property name='taskService' inject='taskService@task-commands';

	/**
	* @taskFile Path to the Task CFC that you want to run
	* @target Method in Task CFC to run
	*/
	function run(
		string taskFile='task.cfc',
		string target='run'
		) {

		arguments.taskFile = fileSystemUtil.resolvePath( arguments.taskFile );
		var taskArgs = {};

		// Named task args will come through in a struct called args
		// task run :param=value :param2=value2
		if( arguments.keyExists( 'args' ) && isStruct( arguments.args ) ) {
			taskArgs = arguments.args;

		// Positional task args will come through direclty in the arguments scope
		// task run task.cfc run value value2
		} else if( arguments.count() > 1 ) {
			// Make a copy of the arguments scope
			taskArgs = duplicate( arguments );
			// And pull out the two args that were meant for this command
			taskArgs.delete( 'taskFile' );
			taskArgs.delete( 'target' );
		}

		// Run the task!
		// We're printing the output here so we can capture it and pipe or redirect the output from "task run"
		print.text(
			taskService.runTask( taskFile, target, taskArgs )
		);
	}

}
