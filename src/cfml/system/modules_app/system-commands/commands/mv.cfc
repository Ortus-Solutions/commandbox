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
		local.newPath 	= fileSystemUtil.resolvePath( arguments.newPath );
		
		if( path.count() > 1 && !directoryExists( arguments.newPath ) ) {
			error( '[#arguments.newPath#] is not a directory.' );
		}
		
		path.apply( function( thisPath ){
			print.redLine( thisPath );
			// It's a directory
			if( directoryExists( thisPath ) ) {
				// rename directory
				directoryRename( thisPath, newPath, true );
				print.greenLine( "Directory renamed/moved to #newPath#" );
			// It's a file
			} else if( fileExists( thisPath ) ){
				// move file
				fileMove( thisPath, newPath );
				print.greenLine( "File renamed/moved to #newPath#" );
			} else {	
				return error( "File/directory does not exist: #thisPath#" );
			}	
		} );
		
	}
	
}