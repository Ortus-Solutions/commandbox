/**
 * Create a new task.  By default this create a task.cfc with a "run" target.
 *
 * {code}
 * task create
 * {code}
 *
 * You can customize the name of the CFC and and name of the target
 *
 * {code}
 * task create build.cfc createZips
 * {code}
 *
 **/
component {
	/**
	* @name Name of the Task CFC that you want to create
	* @target Method in Task CFC to create
	* @directory The base directory to create your task in and creates the directory if it does not exist. Defaults to current dir.
	* @open Open the task file once it's created
	* @force Overwrite any existing file without asking	
	*/
	function run(
		string name='task',
		string target='run',
		string directory='',
		boolean open=false,
		boolean force=false
		) {
				
		// This will make each directory canonical and absolute
		arguments.directory 		= resolvePath( arguments.directory );

		// Read in Templates
		var taskContent = fileRead( '/task-commands/templates/TaskContent.txt' );

		// Start text replacements
		taskContent = replaceNoCase( taskContent, '|targetName|', arguments.target, 'all' );

		var taskPath = '#arguments.directory##arguments.name#.cfc';
		// Create dir if it doesn't exist
		directorycreate( getDirectoryFromPath( taskPath ), true, true );

		// Confirm it
		if( !force && fileExists( taskPath ) && !confirm( "The file '#getFileFromPath( taskPath )#' already exists, overwrite it (y/n)?" ) ){
			print.redLine( "Exiting..." );
			return;
		}

		// Write out the files
		file action='write' file='#taskPath#' mode ='777' output='#taskContent#';
		print.greenLine( 'Created #taskPath#' );

		// open file
		if( arguments.open ){ openPath( taskPath ); }
	}

}
