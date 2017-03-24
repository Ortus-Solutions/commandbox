/**
 * Copy a file or directory.
 * .
 * Create a copy of sample.html in the current directory and call it test.html
 * {code:bash}
 * cp sample.html test.html
 * {code}
 * .
 * Create a copy index.cfm in another directory with the same name
 * {code:bash}
 * cp index.cfm testing/index.cfm
 * {code}
 * .
 * Create a copy of a directory
 * {code:bash}
 * cp foo/ bar/
 * {code}
 *
 **/	
component aliases="copy" {

	/**
	 * @path.hint The file or directory source
	 * @newPath.hint The new name file or directory location
	 * @recurse.hint If true, copies the subdirectories, otherwise only the files in the source directory.
	 * @filter.hint A directory copy filter string that uses "*" as a wildcard, for example, "*.cfm"
	 **/
	function run( required Globber path, required newPath, boolean recurse=false, string filter="*" )  {
		
		// Make path canonical and absolute
		var thisNewPath = fileSystemUtil.resolvePath( arguments.newPath );
		
		if( path.count() > 1 && !directoryExists( thisNewPath ) ) {
			error( '[#thisNewPath#] is not a directory.' );
		}
		
		path.apply( function( thisPath ){
			
			// It's a directory
			if( directoryExists( thisPath ) ) {
				// rename directory
				directoryCopy( thisPath, thisNewPath, arguments.recurse, arguments.filter, true );
				print.greenLine( "Directory copied to #thisNewPath#" );
			// It's a file
			} else if( fileExists( thisPath ) ){
				// Copy file
				DirectoryCreate( getDirectoryFromPath( thisNewPath ), true, true );
				fileCopy( thisPath, thisNewPath );
				print.greenLine( "File copied to #thisNewPath#" );
			} else {	
				return error( "File/directory does not exist: #thisPath#" );
			}
				
		} );
	}
	
}