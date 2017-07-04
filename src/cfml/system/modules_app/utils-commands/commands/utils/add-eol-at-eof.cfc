/**
 * 
 * Ensure files have a trailing newline to adhere to POSIX standard.  Operates on a single file
 * or multiple files as defined by a file globbing pattern.
 * 
 * {code:bash}
 * eol **.cf*
 * {code}
 * 
 * To skip the confirmation, use the --force flag.
 * 
 * {code:bash}
 * eol models/**.cfc --force
 * {code}
 * 
 * Print the file path of each file affected with the --verbose flag.
 * 
 * {code:bash}
 * eol includes/*.cfm --verbose
 * {code}
 * 
 * Exclude a list a globber patterns
 * 
 * {code:bash}
 * eol ** *.png,node_modules/
 * {code}
 * 
 * You can set global default parameters for this command to use like so:
 * 
 * {code:bash}
 * config set command.defaults.eol.force=true
 * config set command.defaults.eol.verbose=true
 * config set command.defaults.eol.exclude=.git/,*.png
 * {code}
 * 
**/
component aliases="eol" {
	property name="pathPatternMatcher" inject="provider:pathPatternMatcher@globber";

	/**
	* @files A file globbing pattern that matches one or more files
	* @exclude  A list of globbing patterns to ignore
	* @force Skip user confirmation of modiying files
	* @verbose Output additional information about each file affected
	*/
	public function run(
		required Globber files,
		String exclude = "",
		Boolean force = false,
		Boolean verbose = false
	){
		arguments.files = filterFiles( arguments.files, arguments.exclude );
		var count = arguments.files.len();

		if ( !arguments.force && !shell.confirm( "Confirm adding EOL at EOF for #count# #count != 1 ? "files" : "file"#" ) ){
			return;
		}

		for ( var file in arguments.files ){
			if ( arguments.verbose ){
				print.line( "Adding EOL at EOF to " & file & "..." );
			}

			addEOL( file );
		}
	}

	private function addEOL( filePath ){
		// trim and get line endings
		var content = rTrim( fileRead( arguments.filePath ) );

		// Add single newline to file content
		content &= getLineEndings( content );

		// write new file
		fileWrite( arguments.filePath, content );
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

	private function getLineEndings( data ){
		if ( arguments.data.len() > 0 ){
			if ( arguments.data[ 1 ].find( chr( 13 ) & chr( 10 ) ) != 0 ){
				return chr( 13 ) & chr( 10 );
			} else if ( arguments.data[ 1 ].find( chr( 13 ) ) != 0 ){
				return chr( 13 );
			}
		}

		return chr( 10 );
	}
}
