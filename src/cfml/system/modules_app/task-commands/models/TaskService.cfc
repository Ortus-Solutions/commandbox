/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle running tasks
*/
component singleton accessors=true {

	// DI Properties
	property name='FileSystemUtil' inject='FileSystem';
	property name='logger' inject='logbox:logger:{this}';
	property name='cr' inject='cr@constants';
	property name='wirebox' inject='wirebox';
	property name='shell' inject='Shell';
	property name='CommandService' inject='CommandService';
	property name='consoleLogger' inject='logbox:logger:console';

	function onDIComplete() {
		// Check if base task class mapped?
		if( NOT wirebox.getBinder().mappingExists( 'commandbox.system.BaseTask' ) ){
			// feed the base class
			wirebox.registerNewInstance( name='commandbox.system.BaseTask', instancePath='commandbox.system.BaseTask' )
				.setAutowire( false );
		}
	}

	/**
	* Runs a task
	*
	* @taskFile Path to the Task CFC that you want to run
	* @target Method in Task CFC to run
	* @taskArgs Struct of arguments to pass on to the task
	*
	* @returns The output of the task.  It's up to the caller to output it.
	*/
	string function runTask( required string taskFile,  required string target='run', taskArgs={} ) {

		// This is neccessary so changes to tasks get picked up right away.
		pagePoolClear();

		// We need the .cfc extension for the file exists check to work.
		if( right( taskFile, 4 ) != '.cfc' ) {
			taskFile &= '.cfc';
		}

		if( !fileExists( taskFile ) ) {
			throw( message="Task CFC doesn't exist.", detail=arguments.taskFile, type="commandException");
		}

		// Create an instance of the taskCFC.  To prevent caching of the actual code in the task, we're treating them as
		// transients. Since is since the code is likely to change while devs are building and testing them.
		var taskCFC = createTaskCFC( taskFile );

		// If target doesn't exist or isn't a UDF
		if( !structKeyExists( taskCFC, target ) || !IsCustomFunction( taskCFC[ target ] ) ) {
			throw( message="Target [#target#] doesn't exist in Task CFC.", detail=arguments.taskFile, type="commandException");
		}

		CommandService.ensureRequiredparams( taskArgs, getMetadata( taskCFC[ target ] ).parameters );

		// Run the task
		taskCFC[ target ]( argumentCollection = taskArgs );

		// Return any output.  It's up to the caller to output it.
		// This is so task output can be correctly captured and piped or redirected to a file.
		return taskCFC.getResult();

	}


	function createTaskCFC( required string taskFile ) {
		// Convert to use a mapping
		var relTaskFile = FileSystemUtil.makePathRelative( taskFile );

		// Strip .cfc back off
		relTaskFile = mid( relTaskFile, 1, len( relTaskFile ) - 4 );
		relTaskFile = relTaskFile.listChangeDelims( '.', '/' );
		relTaskFile = relTaskFile.listChangeDelims( '.', '\' );

		// Create this Task CFC
		try {

			// Check if task mapped?
			if( NOT wirebox.getBinder().mappingExists( "task-" & relTaskFile ) ){
				// feed this task to wirebox with virtual inheritance
				wirebox.registerNewInstance( name="task-" & relTaskFile, instancePath=relTaskFile )
					.setVirtualInheritance( "commandbox.system.BaseTask" );
			}
			// retrieve, build and wire from wirebox
			return wireBox.getInstance( "task-" & relTaskFile );

		// This will catch nasty parse errors and tell us where they happened
		} catch( any e ){
			// Log the full exception with stack trace
			consoleLogger.error( 'Error creating Task [#relTaskFile#].' );
			rethrow;
		}

	}
}
