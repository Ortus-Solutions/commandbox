/**
 * List the files and folders in a directory.  Defaults to current working directory
 * .
 * {code:bash}
 * dir samples/
 * {code}
 * .
 * Use the "recurse" paramater to show all nested files and folders.
 * .
 * {code:bash}
 * dir samples/ --recurse
 * {code}
 *
 **/
component aliases="ls,ll,directory" {

	/**
	 * @directory.hint The directory to list the contents of or a file Globbing path to filter on
	 * @recurse.hint Include nested files and folders
	 **/
	function run( Globber directory=globber( ( getCWD().endsWith( '/' ) || getCWD().endsWith( '\' )  ? getCWD() : getCWD() & '/' ) ), Boolean recurse=false )  {

		// If the user gives us an existing directory foo, change it to the
		// glob pattern foo/* or foo/** if doing a recursive listing.
		if( directoryExists( directory.getPattern() ) ){
			directory.setPattern( directory.getPattern() & '*' & ( recurse ? '*' : '' ) );
		}

		// TODO: Add ability to re-sort this based on user input
		var results = directory
			.asQuery()
			.matches();

		for( var x=1; x lte results.recordcount; x++ ) {
			var printCommand = ( results.type[ x ] eq "File" ? "green" : "white" );

			print[ printCommand & "line" ](
				results.type[ x ] & " " &
				( results.type[ x ] eq "Dir" ? " " : "" ) & //padding
				results.attributes[ x ] & " " &
				numberFormat( results.size[ x ], "999999999" ) & " " &
				dateTimeFormat( results.dateLastModified[ x ], "MMM dd,yyyy HH:mm:ss" ) & " " &
				cleanRecursiveDir( arguments.directory.getBaseDir(), results.directory[ x ] ) & results.name[ x ] & ( results.type[ x ] == "Dir" ? "/" : "" )
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
		var prefix = ( replacenocase( expandPath( arguments.incoming ), expandPath( arguments.directory ), "" ) );
		return ( len( prefix ) ? reReplace( prefix, "^(/|\\)", "" ) & "/" : "" );
	}

}