/**
 * - Usage
 * .
 * Remove trailing spaces from a list of files
 * .
 * {code:bash}
 * utils remove-trailing-spaces globber-filter
 * {code}
 * .
 * No-confirm
 * .
 * {code:bash}
 * utils remove-trailing-spaces globber-filter --force
 * {code}
 * .
 * Print the file path of each file affected
 * .
 * {code:bash}
 * utils remove-trailing-spaces globber-filter --verbose
 * {code}
 * .
 * Exclude a list a globber patterns
 * .
 * {code:bash}
 * utils remove-trailing-spaces globber-filter *.png,node_modules/
 * {code}
 * .
 * Set default force parameter
 * {code:bash}
 * config set command.defaults.rts.force=true
 * {code}
 * .
 * Set default verbose parameter
 * {code:bash}
 * config set command.defaults.rts.verbose=true
 * {code}
 * .
 * Set default exclude patterns
 * {code:bash}
 * config set command.defaults.rts.exclude=.git/,*.png
 * {code}
**/
component aliases="rts" {
	property name="pathPatternMatcher" inject="provider:pathPatternMatcher@globber";

	public function run(
		required Globber files,
		String exclude = "",
		Boolean force = false,
		Boolean verbose = false
	){
		arguments.files = filterFiles( arguments.files, arguments.exclude );
		var count = arguments.files.len();

		if ( !arguments.force && !shell.confirm( "Confirm removing trailing spaces from #count# #count != 1 ? "files" : "file"#" ) ){
			return;
		}

		for ( var file in arguments.files ){
			if ( arguments.verbose ){
				print.line( "Removing trailing spaces from " & file & "..." );
			}

			removeTrailingSpaces( file );
		}
	}

	private function removeTrailingSpaces( filePath ){
		// trim trailing spaces and get line endings
		var trimLinesResult = fileTrimLines( arguments.filePath );

		// write new file
		fileWrite( arguments.filePath, arrayToList( trimLinesResult.lines, trimLinesResult.lineEndings ) );
	}

	private function fileTrimLines( filePath ){
		var lines = [];
		var lineEndings = "";

		cfloop( file=filePath, index="line" ){
			// get the file line endings
			if ( lineEndings == "" ){
				lineEndings = getLineEndings( line );
			}
			// trim the trailing spaces
			lines.append( rTrim( line ) );
		}

		return { lines: lines, lineEndings: lineEndings };
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
