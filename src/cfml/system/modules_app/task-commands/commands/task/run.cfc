/**
 * Run a task
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