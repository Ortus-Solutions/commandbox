/**
 * Lists the files and folders in a given directory.  Defaults to current working directory
 *
 * dir samples
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="ls,ll,directory" excludeFromHelp=false {

	/**
	 * @directory.hint The directory to list the contents of
	 * @recurse.hint recursively list
	 **/
	function run( String directory="", Boolean recurse=false )  {
		// This will make each directory canonical and absolute		
		arguments.directory = fileSystemUtil.resolveDirectory( arguments.directory );
		
		var results = directoryList( arguments.directory, arguments.recurse, "query" );
		for( var x=1; x lte results.recordcount; x++ ) {
			var printCommand = ( results.type[ x ] eq "File" ? "green" : "purple" );

			print[ printCommand & "line" ]( 
				results.type[ x ] & " " &
				( results.type[ x ] eq "Dir" ? " " : "" ) & //padding
				results.attributes[ x ] & " " &
				numberFormat( results.size[ x ], "999999999" ) & " " &
				dateTimeFormat( results.dateLastModified[ x ], "MMM dd,yyyy HH:mm:ss" ) & " " &
				cleanRecursiveDir( arguments.directory, results.directory[ x ] ) & results.name[ x ]				
			);
		}

		if( results.recordcount eq 0 ){
			print.orangeLine( "No files/directories found." );
		}
	}

	/**
	* Cleanup directory recursive nesting
	*/
	private function cleanRecursiveDir( required directory, required incoming ){
		var prefix = ( replacenocase( arguments.incoming, arguments.directory, "" ) );
		return ( len( prefix ) ? reReplace( prefix, "^(/|\\)", "" ) & "/" : "" );
	}


}