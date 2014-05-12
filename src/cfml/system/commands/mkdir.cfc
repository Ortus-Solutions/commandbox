/**
 * Creates a new directory
 *
 * mkdir newDir
 * 
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @directory.hint The directory to create
	 **/
	function run( required String directory )  {
				
		// Validate directory
		if( !len( directory ) ) {
			return error( 'Please provide a directory name.' );			
		}
		
		// This will make each directory canonical and absolute		
		directory = fileSystemUtil.resolveDirectory( directory );
			
		// Create dir.  Ignore if it exists and also create parent folders if missing
		directorycreate( directory, true, true );
			
		print.greenLine( 'Created #directory#' );
	}


}