/**
 * Delete a file or directory from the filesystem.  This command will not delete non-empty directories
 * unless you use the "recurse" param. Use the "force" param to supress the confirmation.
 *
 * delete sample.html
 *
 **/	
component extends="commandbox.system.BaseCommand" aliases="rm,del" excludeFromHelp=false {

	/**
	 * @path.hint file or directory to delete
	 * @force.hint Force deletion without asking
	 * @recurse.hint Delete sub directories
	 **/
	function run( required path, Boolean force=false, Boolean recurse=false )  {
		
		// Make path canonical and absolute
		arguments.path = fileSystemUtil.resolvePath( arguments.path );
			
		// It's a directory
		if( directoryExists( arguments.path ) ) {
								
				var subMessage = arguments.recurse ? ' and all its subdirectories' : '';
				
				if( arguments.force || isAffirmative( shell.ask( "Delete #path##subMessage#? [y/n] : " ) ) ) {
					
					if( directoryList( arguments.path ).len() && !arguments.recurse ) {
						return error( 'Directory [#arguments.path#] is not empty! Use the "recurse" parameter to override' );
					}
					
					directoryDelete( arguments.path, recurse );
					print.greenLine( "Deleted #arguments.path#" );
				} else {
					print.redLine( "Cancelled!" );					
				}
				
			
		// It's a file
		} else if( fileExists( arguments.path ) ){
						
			if( arguments.force || isAffirmative( shell.ask( "Delete #path#? [y/n] : " ) ) ) {
				
				fileDelete( arguments.path );
				print.greenLine( "Deleted #arguments.path#" );
			} else {
				print.redLine( "Cancelled!" );					
			}
			
		} else {	
			return error( "File/directory does not exist: #arguments.path#" );
		}
	}
	
}