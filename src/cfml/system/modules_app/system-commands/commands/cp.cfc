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
	function run( required path, required newPath, boolean recurse=false, string filter="*" )  {
		
		// Make path canonical and absolute
		arguments.path 		= fileSystemUtil.resolvePath( arguments.path );
		arguments.newPath 	= fileSystemUtil.resolvePath( arguments.newPath );
		
		// It's a directory
		if( directoryExists( arguments.path ) ) {
			// rename directory
			directoryCopy( arguments.path, arguments.newPath, arguments.recurse, arguments.filter, true );
			print.greenLine( "Directory copied to #arguments.newPath#" );
		// It's a file
		} else if( fileExists( arguments.path ) ){
			// Copy file
			DirectoryCreate( getDirectoryFromPath( arguments.newPath ), true, true );
			fileCopy( arguments.path, arguments.newPath );
			print.greenLine( "File copied to #arguments.newPath#" );
		} else {	
			return error( "File/directory does not exist: #arguments.path#" );
		}
	}
	
}