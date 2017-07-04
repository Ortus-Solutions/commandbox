/**
 * - Usage
 * .
 * Add trailing newline to a list of files
 * .
 * {code:bash}
 * eol globber-filter
 * {code}
 * .
 * No-confirm
 * .
 * {code:bash}
 * eol globber-filter --force
 * {code}
 * .
 * Print the file path of each file affected
 * .
 * {code:bash}
 * eol globber-filter --verbose
 * {code}
 * .
 * Exclude a list a globber patterns
 * .
 * {code:bash}
 * eol globber-filter *.png,node_modules/
 * {code}
 * .
 * - Configuration
 * .
 * Set default force parameter
 * {code:bash}
 * config set command.defaults.eol.force=true
 * {code}
 * .
 * Set default verbose parameter
 * {code:bash}
 * config set command.defaults.eol.verbose=true
 * {code}
 * .
 * Set default exclude patterns
 * {code:bash}
 * config set command.defaults.eol.exclude=.git/,*.png
 * {code}
**/
component aliases="eol" {
	property name="pathPatternMatcher" inject="provider:pathPatternMatcher@globber";

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
