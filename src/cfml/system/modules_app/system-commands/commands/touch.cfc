/**
 * Create a new file according to its name if it does not exist. If it exists, modify its last updated date and time to now.
 * .
 * {code:bash}
 * touch file.txt
 * {code}
 * .
 * Use the open parameter to open the file in your default editor after creating it
 * .
 * {code:bash}
 * touch index.cfm --open
 * {code}
 *
 * .
 * Use the force parameter to overwrite the contents of the file to be empty even if it exists.
 * .
 * {code:bash}
 * touch file.txt --force
 * {code}
 *
 **/
component aliases="new" {

	/**
	 * @file File or globbing pattern. Creates if not existing, otherwise updates timestamp
	 * @force If forced, then file will be recreated even if it exists
	 * @open Open the file after creating it
 	 **/
	function run(
		required Globber file,
		boolean force=false,
		boolean open=false )  {

		// Get matching paths
		var matches = file.matches();

		// If no paths were found and the pattern isn't a glob, just use the pattern (it's a new file).
		if( !file.count() && !( file.getPattern() contains '*' ) && !( file.getPattern() contains '?' ) ) {
			matches.append( file.getPattern() );
		}

		for( var theFile in matches ) {

			var oFile = createObject( "java", "java.io.File" ).init( theFile );
			var fileName = listLast( theFile, "/" );

			// if we have a force, recreate the file
			if( arguments.force and oFile.exists() ){
				oFile.delete();
			}

			// check for update or creation
			if( !oFile.exists() ){
				oFile.createNewFile();
				print.line( "#fileName# created!" );
			} else {
				oFile.setLastModified( now().getTime() );
				print.line( "#fileName# last modified bit updated!" );
			}

			// Open file for the user
			if( arguments.open ){
				// Defer to the "edit" command.
				command( 'edit' )
					.params( theFile )
					.run();
			}

		}

	}

}