/**
 *
 * Normalizes the indentation for a file or set of files
 *
 * {code:bash}
 * indents **.cf* tabs
 * {code}
 *
 * Change the number of spaces per tab
 *
 * {code:bash}
 * indents **.cf* tabs 2
 * {code}
 *
 * To skip the confirmation, use the --force flag.
 *
 * {code:bash}
 * indents models/**.cfc --force
 * {code}
 *
 * Print the file path of each file affected with the --verbose flag.
 *
 * {code:bash}
 * indents includes/*.cfm --verbose
 * {code}
 *
 * Exclude a list a globber patterns
 *
 * {code:bash}
 * indents ** *.png,node_modules/
 * {code}
 *
 * You can set global default parameters for this command to use like so:
 *
 * {code:bash}
 * config set command.defaults.indents.force=true
 * config set command.defaults.indents.verbose=true
 * config set command.defaults.indents.exclude=.git/,*.png
 * {code}
 *
**/
component aliases="indents" {
	property name="pathPatternMatcher" inject="provider:pathPatternMatcher@globber";

	/**
	* @files A file globbing pattern that matches one or more files
	* @spacesOrTabs Convert to spaces or tabs
	* @spaceTabCount The number of spaces per tab
	* @exclude A list of globbing patterns to ignore
	* @force Skip user confirmation of modiying files
	* @verbose Output additional information about each file affected
	* @roundUp Convert additional spaces that don't equal a tab to a full tab
	*/
	public function run(
		required Globber files,
		String spacesOrTabs = 'spaces',
		Number spaceTabCount = 4,
		String exclude = "",
		Boolean force = false,
		Boolean verbose = false,
		boolean roundUp=false
	){
		arguments.files = filterFiles( arguments.files, arguments.exclude );
		var count = arguments.files.len();

		if ( !arguments.force && !shell.confirm( "Confirm normalizing indents for #count# #count != 1 ? "files" : "file"#" ) ){
			return;
		}

		for ( var file in arguments.files ){
			normalizeIndents( file, arguments.verbose, arguments.spacesOrTabs, arguments.spaceTabCount, roundUp );
		}
	}

	private function normalizeIndents( filePath, verbose, spacesOrTabs, spaceTabCount, roundUp ){
		var trimLinesResult = fileNormalizeIndents( arguments.filePath, arguments.spacesOrTabs, arguments.spaceTabCount, roundUp );

		if ( trimLinesResult.fileChanged ){
			if ( arguments.verbose ){
				print.line( "Normalizing indents from " & arguments.filePath & "..." )
					.toConsole();
			}

			// write new file
			fileWrite( arguments.filePath, trimLinesResult.newData );
		}
	}

	private function fileNormalizeIndents( filePath, spacesOrTabs, spaceTabCount, roundUp ){
		var fileData = fileRead( arguments.filePath );
		var newData = javaCast( "string", fileData );

		if ( arguments.spacesOrTabs == "tabs" ) {
			var regex = "(?m)^(\s*)[ ]{" & arguments.spaceTabCount & "}(\s*)";

			while ( reFind( regex, newData ) != 0 ) {
				newData = newData.replaceAll( regex, "$1#chr(9)#$2" );
			}

			newData = newData.replaceAll( "(?m)^(\t*)[ ]+", "$1#(roundUp?chr(9):'')#" )
		} else if ( arguments.spacesOrTabs == "spaces" ) {
			var regex = "(?m)^(\s*)[\t]{1}(\s*)";

			while ( reFind( regex, newData ) != 0 ) {
				newData = newData.replaceAll( regex, "$1" & repeatString( " ", arguments.spaceTabCount ) & "$2" );
			}
		} else {
			error( '[#arguments.spacesOrTabs#] is not a valid option for spacesOrTabs.' );
		}

		return { newData: newData, fileChanged: newData != fileData };
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
