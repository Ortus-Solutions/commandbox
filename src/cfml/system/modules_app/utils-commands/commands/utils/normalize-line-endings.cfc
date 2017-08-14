/**
 *
 * Normalizes the line endings in a file.  Operates on a single file
 * or multiple files as defined by a file globbing pattern.
 *
 * {code:bash}
 * line-endings **.cf*
 * {code}
 *
 * To skip the confirmation, use the --force flag.
 *
 * {code:bash}
 * line-endings models/**.cfc --force
 * {code}
 *
 * Print the file path of each file affected with the --verbose flag.
 *
 * {code:bash}
 * line-endings includes/*.cfm --verbose
 * {code}
 *
 * Exclude a list a globber patterns
 *
 * {code:bash}
 * line-endings ** *.png,node_modules/
 * {code}
 *
 * You can set global default parameters for this command to use like so:
 *
 * {code:bash}
 * config set command.defaults.line-endings.force=true
 * config set command.defaults.line-endings.verbose=true
 * config set command.defaults.line-endings.exclude=.git/,*.png
 * {code}
 *
**/
component aliases="line-endings" {
	property name="pathPatternMatcher" inject="provider:pathPatternMatcher@globber";

	/**
	* @files A file globbing pattern that matches one or more files
	* @type Which type of line ending to use, options: [unix, windows, mac]
	* @exclude  A list of globbing patterns to ignore
	* @force Skip user confirmation of modiying files
	* @verbose Output additional information about each file affected
	*/
	public function run(
		required Globber files,
		String type = "unix",
		String exclude = "",
		Boolean force = false,
		Boolean verbose = false
	){
		arguments.files = filterFiles( arguments.files, arguments.exclude );
		var count = arguments.files.len();

		if ( !arguments.force && !shell.confirm( "Confirm normalizing line endings for #count# #count != 1 ? "files" : "file"#" ) ){
			return;
		}

		for ( var file in arguments.files ){
			normalizeLineEndings( file, arguments.type, arguments.verbose );
		}
	}

	private function normalizeLineEndings( filePath, type, verbose ){
		// trim and get line endings
		var content = fileRead( arguments.filePath );

		switch ( arguments.type ) {
			case "unix":
				// windows -> unix
				var newContent = replace( content, chr( 13 ) & chr( 10 ), chr( 10 ), "all" );
				// mac -> unix
				newContent = replace( newContent, chr( 13 ), chr( 10 ), "all" );
				break;

			case "windows":
				// windows -> unix
				var newContent = replace( content, chr( 13 ) & chr( 10 ), chr( 10 ), "all" );
				// mac -> unix
				newContent = replace( newContent, chr( 13 ), chr( 10 ), "all" );
				// unix -> windows
				newContent = replace( newContent, chr( 10 ), chr( 13 ) & chr( 10 ), "all" );
				break;

			case "mac":
				// windows -> mac
				var newContent = replace( content, chr( 13 ) & chr( 10 ), chr( 13 ), "all" );
				// unix -> mac
				newContent = replace( newContent, chr( 10 ), chr( 13 ), "all" );
				break;
		}

		if ( content != newContent ) {
			if ( arguments.verbose ){
				print.line( "Normalizing line endings for " & arguments.filePath & "..." )
					.toConsole();
			}

			// write new file
			fileWrite( arguments.filePath, newContent );
		}
	}

	private function filterFiles( files, exclude ){
		var filteredFiles = [];

		arguments.files.apply( function( file ){
			var fileInfo = getFileInfo( arguments.file );
			// only process files
			if ( fileInfo.type == "file" && !pathPatternMatcher.matchPatterns( listToArray( exclude ), arguments.file ) ){
				filteredFiles.append( arguments.file );
			}
		} );

		return filteredFiles;
	}
}
