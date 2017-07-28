/**
 *
 * Remove those pesky trailing spaces from each line that some editors add.
 * Can be run on a single file or aginst a list of files defined by a file globbing pattern.
 *
 * {code:bash}
 * rts **.cf*
 * {code}
 *
 * Skip the user confirmation with the --force flag.
 *
 * {code:bash}
 * rts models/**.cfc --force
 * {code}
 *
 * Print the file path of each file affected with the --verbose flag.
 *
 * {code:bash}
 * rts includes/*.cfm --verbose
 * {code}
 *
 * Exclude a list a file globbing patterns
 *
 * {code:bash}
 * rts ** *.png,node_modules/
 * {code}
 *
 * You can set global default parameters for this command to use like so:
 *
 * {code:bash}
 * config set command.defaults.rts.force=true
 * config set command.defaults.rts.verbose=true
 * config set command.defaults.rts.exclude=.git/,*.png
 * {code}
 *
**/
component aliases="rts" {
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

		if ( !arguments.force && !shell.confirm( "Confirm removing trailing spaces from #count# #count != 1 ? "files" : "file"#" ) ){
			return;
		}

		for ( var file in arguments.files ){
			removeTrailingSpaces( file, verbose );
		}
	}

	private function removeTrailingSpaces( filePath, verbose ){
		// trim trailing spaces and get line endings
		var trimLinesResult = fileTrimLines( arguments.filePath );

		if ( trimLinesResult.fileChanged ){
			if ( arguments.verbose ){
				print.line( "Removing trailing spaces from " & arguments.filePath & "..." )
					.toConsole();
			}

			// write new file
			fileWrite( arguments.filePath, trimLinesResult.cleanFile );
		}
	}

	private function fileTrimLines( filePath ){
		var fileData = fileRead( arguments.filePath );
		var cleanFile = javaCast( "string", fileData ).replaceAll( "(?m)[ \t]+$", "" );

		return { cleanFile: cleanFile, fileChanged: cleanFile != fileData };
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
