/**
 * Copy a file or directory
 *
 * cp sample.html test.html
 * cp index.cfm testing/index.cfm
 *
 **/	
component extends="commandbox.system.BaseCommand" aliases="copy" excludeFromHelp=false {

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
			fileCopy( arguments.path, arguments.newPath );
			print.greenLine( "File copied to #arguments.newPath#" );
		} else {	
			return error( "File/directory does not exist: #arguments.path#" );
		}
	}
	
}