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
		if( arguments.keyExists( 'args' ) && isStruct( arguments.args ) ) {
			taskArgs = arguments.args;
		} else if( arguments.count() > 1 ) {
			taskArgs = duplicate( arguments );
			taskArgs.delete( 'taskFile' );
			taskArgs.delete( 'target' );
		}
		taskService.runTask( taskFile, target, taskArgs );
	}

}