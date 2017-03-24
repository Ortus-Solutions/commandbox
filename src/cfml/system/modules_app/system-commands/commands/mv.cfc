/**
 * Rename/move a file or directory to a new name and path
 * .
 * Rename a file
 * {code:bash}
 * mv sample.html sample.htm 
 * {code}
 * .
 * Move a file
 * {code:bash}
 * mv sample.html /test/sample.htm
 * {code}
 * .
 * Rename a directory
 * {code:bash}
 * mv foo/ bar/ 
 * {code}
 * .
 * Move a directory
 * {code:bash}
 * mv foo/ bar/foo/ 
 * {code}
 *
 **/	
component aliases="rename" {

	/**
	 * @path.hint The file or directory source to rename
	 * @newPath.hint The new name of the file or directory
	 **/
	function run( required Globber path, required newPath )  {
		
		// Make path canonical and absolute
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