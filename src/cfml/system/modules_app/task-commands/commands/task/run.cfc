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
	* @target.optionsUDF taskTargetOptions
	*/
	function run(
		string taskFile='task.cfc',
		string target='run'
		) {

		arguments.taskFile = resolvePath( arguments.taskFile );
		var taskArgs = {};

		// Named task args will come through in a struct called args
		// task run :param=value :param2=value2
		if( arguments.keyExists( 'args' ) && isStruct( arguments.args ) ) {
			taskArgs = arguments.args;

		// Positional task args will come through directly in the arguments scope
		// task run task.cfc run value value2
		} else if( arguments.count() > 2 && listFind( structKeyList( arguments ), '3' ) ) {
			taskArgs = [];
			var i = 2;
			// Skip first two args, and pass the rest through in position 1, 2, 3, etc
			while( ++i <= arguments.count() ) {
				taskArgs.append( arguments[ i ] );
			}
		}

		// Fix for negated flags like --no:verbose
		if( arguments.keyExists( 'no' ) && isStruct( arguments.no ) ) {
			arguments.no.each( function( k, v ) {
				if( isBoolean( v ) ) {
					taskArgs[ k ] = false;
				}
			} );
		}

		try {

			// Run the task!
			// We're printing the output here so we can capture it and pipe or redirect the output from "task run"
			var results = taskService.runTask( taskFile, target, taskArgs );

		} catch( any e ) {
			rethrow;
		} finally{
			if( shell.getExitCode() != 0 ) {
				setExitCode( shell.getExitCode() );
			}
		}

		return results;
	}

	array function taskTargetOptions( string paramSoFar, struct passedNamedParameters ) {
		var taskFile = resolvePath( passedNamedParameters.taskFile ?: 'task.cfc' );
		try {
			return taskService.getTaskMethods( taskFile );
		} catch ( any e ) {
			// Recover shell prompt from console error output
			getShell().getReader().redrawLine();
		}
		return [];
	}

}
