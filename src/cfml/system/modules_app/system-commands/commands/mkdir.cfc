/**
 * Create a new directory.
 * .
 * {code:bash}
 * mkdir newDir
 * {code}
 *
 * You can also change your current working directory to the new path with the cd flag.
 * .
 * {code:bash}
 * mkdir newDir --cd
 * {code}
 *
 **/
component {

	/**
	 * @directory.hint The directory to create
	 * @cd.hint CD into the directory after creating
	 **/
	function run( required String directory, boolean cd=false )  {

		// Validate directory
		if( !len( arguments.directory ) ) {
			return error( 'Please provide a directory name.' );
		}

		// This will make each directory canonical and absolute
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );

		// Create dir.  Ignore if it exists and also create parent folders if missing
		directorycreate( arguments.directory, true, true );

		print.greenLine( 'Created #arguments.directory#' );

		// Optionally change into the new dir
		if( arguments.cd ) {
			command( 'cd' )
				.params( arguments.directory )
				.run();
		}

	}


}
