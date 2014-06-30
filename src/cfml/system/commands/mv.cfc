/**
 * Rename/move a file or directory to a new name and path
 *
 * mv sample.html sample.htm
 * rename test.cf test.cfm
 *
 **/	
component extends="commandbox.system.BaseCommand" aliases="rename" excludeFromHelp=false {

	/**
	 * @path.hint The file or directory source to rename
	 * @newPath.hint The new name of the file or directory
	 **/
	function run( required path, required newPath )  {
		
		// Make path canonical and absolute
		arguments.path 		= fileSystemUtil.resolvePath( arguments.path );
		arguments.newPath 	= fileSystemUtil.resolvePath( arguments.newPath );
		
		// It's a directory
		if( directoryExists( arguments.path ) ) {
			// rename directory
			directoryRename( arguments.path, arguments.newPath, true );
			print.greenLine( "Directory renamed/moved to #arguments.newPath#" );
		// It's a file
		} else if( fileExists( arguments.path ) ){
			// move file
			fileMove( arguments.path, arguments.newPath );
			print.greenLine( "File renamed/moved to #arguments.newPath#" );
		} else {	
			return error( "File/directory does not exist: #arguments.path#" );
		}
	}
	
}