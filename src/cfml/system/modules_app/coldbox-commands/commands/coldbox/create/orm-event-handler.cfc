/**
* Create a new ORM Event Handler in an existing ColdBox application.  Make sure you are running this command in the root
* of your app for it to find the correct folder.
* .
* {code:bash}
* coldbox create orm-event-handler MyEventHandler --open
* {code}
*
 **/
component {

	/**
	* @name.hint Name of the event handler to create without the .cfc. For packages, specify name as 'myPackage/myModel'
	* @directory.hint The base directory to create your event handler in and creates the directory if it does not exist.
	* @open.hint Open the file once generated
	**/
	function run(
		required name,
		directory='models',
		boolean open=false
	) {
		// This will make each directory canonical and absolute
		arguments.directory 		= fileSystemUtil.resolvePath( arguments.directory );

		// Validate directory
		if( !directoryExists( arguments.directory ) ) {
			directoryCreate( arguments.directory );
		}

		// Allow dot-delimited paths
		arguments.name = replace( arguments.name, '.', '/', 'all' );
		// This help readability so the success messages aren't up against the previous command line
		print.line();

		// Read in Template
		var modelContent = fileRead( '/coldbox-commands/templates/orm/ORMEventHandler.txt' );

		// Write out the model
		var modelPath = '#directory#/#arguments.name#.cfc';
		// Create dir if it doesn't exist
		directorycreate( getDirectoryFromPath( modelPath ), true, true );
		file action='write' file='#modelPath#' mode ='777' output='#modelContent#';
		print.greenLine( 'Created #modelPath#' );

		// Open file?
		if( arguments.open ){ openPath( modelPath ); }
	}

}