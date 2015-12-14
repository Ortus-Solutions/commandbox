/**
 * Create a new directory.
 * .
 * {code:bash}
 * mkdir newDir 
 * {code}
 **/
component {

	/**
	 * @directory.hint The directory to create
	 **/
	function run( required String directory )  {
				
		// Validate directory
		if( !len( arguments.directory ) ) {
			return error( 'Please provide a directory name.' );			
		}
		
		// This will make each directory canonical and absolute		
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
			
		// Create dir.  Ignore if it exists and also create parent folders if missing
		directorycreate( arguments.directory, true, true );
			
		print.greenLine( 'Created #arguments.directory#' );
	}


}