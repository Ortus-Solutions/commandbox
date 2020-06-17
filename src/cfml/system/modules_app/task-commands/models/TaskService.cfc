/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle excuction of Task Runners
*/
component singleton accessors=true {

	// DI Properties
	property name='FileSystemUtil'	inject='FileSystem';
	property name='logger'			inject='logbox:logger:{this}';
	property name='cr'				inject='cr@constants';
	property name='wirebox'			inject='wirebox';
	property name='shell'			inject='Shell';
	property name='CommandService'	inject='CommandService';
	property name='consoleLogger'	inject='logbox:logger:console';
	property name='metadataCache'	inject='cachebox:metadataCache';
	property name='job'				inject='interactiveJob';

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
	* @topLevel false for target dependecy runs
	*
	* @returns The output of the task.  It's up to the caller to output it.
	*/
	string function runTask( required string taskFile,  required string target='run', taskArgs={}, boolean topLevel=true ) {

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
		// transients. Since the code is likely to change while devs are building and testing them.
		var taskCFC = createTaskCFC( taskFile );

		// If target doesn't exist or isn't a UDF
		if( !taskHasMethod( taskCFC, target ) ) {
			throw( message="Target [#target#] doesn't exist in Task CFC.", detail=arguments.taskFile, type="commandException");
		}

		var targetMD = getMetadata( taskCFC[ target ] );
		if( isArray( taskargs ) ) {
			taskargs = commandService.convertToNamedParameters( taskargs, targetMD.parameters );
		}
		commandService.ensureRequiredparams( taskargs, targetMD.parameters );
		
		try {
			
			// Check for, and run target dependencies
			var taskDeps = targetMD.depends ?: '';
			taskDeps.listToArray()
				.each( function( dep ) {
					taskCFC.getPrinter().print( runTask( taskFile, dep, taskArgs, false ) );
				} );
			
			// Build our initial wrapper UDF for invoking the target.  This has embedded into it the logic for the pre<target> and post<target> lifecycle events
			var invokeUDF = ()=>{
			
				invokeLifecycleEvent( taskCFC, 'pre#target#', { target:target, taskargs:taskargs } );

				var refLocal = taskCFC[ target ]( argumentCollection = taskArgs );

				invokeLifecycleEvent( taskCFC, 'post#target#', { target:target, taskargs:taskargs } );
				
				if( isNull( refLocal ) ) {
					return;
				} else {
					return refLocal;
				}
			}
			
			// Since these UDF will execute from the inside out, wrap out UDF in the around<target> event first...
			invokeUDF = wrapLifecycleEvent( taskCFC, 'around#target#', { target:target, taskargs:taskargs, invokeUDF:invokeUDF } );
			// .. Then wrap that in our aroundTask event second
			invokeUDF = wrapLifecycleEvent( taskCFC, 'aroundTask', { target:target, taskargs:taskargs, invokeUDF:invokeUDF } );
			
			// Run the task
			local.returnedExitCode = invokeUDF();
		 } catch( any e ) {
		 	
			// If this task didn't already set a failing exit code...
			if( taskCFC.getExitCode() == 0 ) {
				// Go ahead and set one for it.  The shell will inherit it below in the finally block.
				if( val( e.errorCode ?: 0 ) > 0 ) {
					taskCFC.setExitCode( e.errorCode );
				} else {
					taskCFC.setExitCode( 1 );
				}
			}
			
			if( topLevel ) {
				invokeLifecycleEvent( taskCFC, 'onError', { target:target, taskargs:taskargs, exception=e } );
			}
			
			rethrow;
			
		 } finally {
		 	
			// Set task exit code into the shell
		 	if( !isNull( local.returnedExitCode ) && isSimpleValue( local.returnedExitCode ) ) {
		 		var finalExitCode = val( local.returnedExitCode );
		 	} else {
				var finalExitCode = taskCFC.getExitCode();
		 	}
			shell.setExitCode( finalExitCode );
			
			if( topLevel ) {
				if( finalExitCode == 0 ) {
					invokeLifecycleEvent( taskCFC, 'onSuccess', { target:target, taskargs:taskargs } );
				} else {
					invokeLifecycleEvent( taskCFC, 'onFail', { target:target, taskargs:taskargs } );
				}
				invokeLifecycleEvent( taskCFC, 'onComplete', { target:target, taskargs:taskargs } );
			}
			
			if( finalExitCode != 0 ) {
				// Dump out anything the task had printed so far
				var result = taskCFC.getResult();
				taskCFC.getPrinter().clear();
				if( len( result ) ){
					shell.printString( result );
				}
			}
			
		 }
	 
		// If the previous Task failed
		if( finalExitCode != 0 ) {
			
			if( job.isActive() ) {
				job.errorRemaining( message );
				// Distance ourselves from whatever other output the Task may have given so far.
				shell.printString( chr( 10 ) );
			}
			
			// Dump out anything the task had printed so far
			var result = taskCFC.getResult();
			if( len( result ) ){
				shell.printString( result & cr );
			}
			
			throw( message='Task returned failing exit code (#finalExitCode#)', detail='Failing Task: #taskFile# #target#', type="commandException", errorCode=finalExitCode );
		}
		

		// Return any output.  It's up to the caller to output it.
		// This is so task output can be correctly captured and piped or redirected to a file.
		return taskCFC.getResult();

	}

	/**
	* Returns the public methods in a task component
	*
	* @taskFile Path to the Task CFC
	*
	* @returns An array of public method names
	*/
	array function getTaskMethods( required string taskFile ) {
		pagePoolClear();

		if( right( taskFile, 4 ) != '.cfc' ) {
			taskFile &= '.cfc';
		}

		if( !fileExists( taskFile ) ) {
			return [];
		}

		var taskCFC = createTaskCFC( taskFile );
		return getMetadata( taskCFC ).functions
			.filter( ( f ) => f.access == 'public' )
			.map( ( f ) => f.name );
	}

	/**
	* Creates Task CFC instance from absolute file path
	* 
	* @taskFile Absolute path to task CFC to create.
	*/
	function createTaskCFC( required string taskFile ) {
		// Convert to use a mapping
		var relTaskFile = FileSystemUtil.makePathRelative( taskFile );

		// Strip .cfc back off
		relTaskFile = mid( relTaskFile, 1, len( relTaskFile ) - 4 );
		relTaskFile = relTaskFile.listChangeDelims( '.', '/' );
		relTaskFile = relTaskFile.listChangeDelims( '.', '\' );

		metadataCache.clear( relTaskFile );		

		// Create this Task CFC
		try {
			var mappingName = '"task-" & relTaskFile';
			
			// Check if task mapped?
			if( wirebox.getBinder().mappingExists( mappingName ) ){
				// Clear it so metadata can be refreshed.
				wirebox.getBinder().unMap( mappingName );
			}
			
			// feed this task to wirebox with virtual inheritance
			wirebox.registerNewInstance( name=mappingName, instancePath=relTaskFile )
				.setVirtualInheritance( "commandbox.system.BaseTask" );
				
			// retrieve, build and wire from wirebox
			return wireBox.getInstance( mappingName );

		// This will catch nasty parse errors and tell us where they happened
		} catch( any e ){
			// Log the full exception with stack trace
			consoleLogger.error( 'Error creating Task [#relTaskFile#].' );
			rethrow;
		}

	}
	
	/**
	* Convenience method to determine if a Task CFC instance has a given method name
	* 
	* @taskCFC The actual Task CFC instance
	* @method Name of method to check for
	*
	* @returns boolean True if method exists, false if otherwise.
	*/
	boolean function taskHasMethod( any taskCFC, string method ) {
		if( structKeyExists( taskCFC, method ) && isCustomFunction( taskCFC[ method ] ) ) {
			return true;
		}
		return false;
	}
	
	/**
	* Determines if a lifecycle event can run based on the this.XXX_only and this.XXX_except variables in the task CFC instance.
	* 
	* @taskCFC The actual Task CFC instance
	* @eventname Name of the lifecycle event to check
	* @target Name of the task target requesting the lifecycle event
	*/
	boolean function canLifecycleEventRun( any taskCFC, string eventName, string target ) {
		if( listFindNoCase( 'preTask,postTask,aroundTask,onComplete,onSuccess,onFail,onError', eventName ) ) {
			var eventOnly = listMap( taskCFC[ eventName & '_only' ] ?: '', (e)=>trim( e ) );
			var eventExcept = listMap( taskCFC[ eventName & '_except' ] ?: '', (e)=>trim( e ) );
			if(
				( len( eventOnly ) == 0 || eventOnly.listFindNoCase( target ) )
				&&
				( len( eventExcept ) == 0 || !eventExcept.listFindNoCase( target ) )
			) {
				return true;
			}
			return false;
		}
		return true;
	}
	
	/**
	* Optionally invokes a lifecyle event based on whether it exists and is valid to be called.
	* 
	* @taskCFC The actual Task CFC instance
	* @eventname Name of the lifecycle event to call
	* @args The args of the actual target method
	*/
	function invokeLifecycleEvent( any taskCFC, string eventName, struct args={} ) {
		if( taskHasMethod( taskCFC, eventName ) && canLifecycleEventRun( taskCFC, eventName, args.target ) ) {
			taskCFC[ eventName ]( argumentCollection=args );
		}
	}
	
	/**
	* Accepts a UDF and wraps it in another callback that adds additional functionality to it, creating a chain of callbacks.
	* 
	* @taskCFC The actual Task CFC instance
	* @eventname Name of the lifecycle event to wrap
	* @args The args of the actual target method
	*/
	function wrapLifecycleEvent( any taskCFC, string eventName, struct args={} ) {
			// This higher order function returns another function reference for the caller to invoke
			return ()=>{
				
				// If this is the around<target> event, fire preTask
				if( eventname == 'around#args.target#' ) {
					invokeLifecycleEvent( taskCFC, 'preTask', { target:args.target, taskargs:args.taskargs } );
				}

				// If there is no aroundXXX event in this CFC, we just call the callback up the chain
				if( taskHasMethod( taskCFC, eventName ) && canLifecycleEventRun( taskCFC, eventName, args.target ) ) {
					var refLocal = taskCFC[ eventName ]( argumentCollection = args );
				} else {
					var refLocal = args.invokeUDF();
				}					
				
				// If this is the around<target> event, fire postTask
				if( eventname == 'around#args.target#' ) {
					invokeLifecycleEvent( taskCFC, 'postTask', { target:args.target, taskargs:args.taskargs } );
				}
				
				if( isNull( refLocal ) ) {
					return;
				} else {
					return refLocal;
				}				
			}
		
	}
	
}
