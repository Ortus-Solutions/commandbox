/**
 * Removes the trailing spaces from a file
 * .
 * {code:bash}
 * utils remove-trailing-spaces /home/contentbox/index.cfm
 * {code}
 * .
 * Removes the trailing spaces from a directory
 * .
 * {code:bash}
 * utils remove-trailing-spaces /home/contentbox
 * {code}
**/
component aliases="rts" {
	/**
	 * @path The file or directory path of a file to remove trailing spaces from
	 **/
	function run( path="" ){
		variables.excludeExtensions = getExcludeExtensions();

		if ( arguments.path == "" ) {
			print.line( "Please provide a file or folder path" );
			return;
		}

		// try adding the file to the current working directory if the file doesn't exist
		if ( fileExists( arguments.path ) ){
			// file exists
		} else if ( fileExists( getCWD() & "/" & arguments.path ) ){
			arguments.path = getCWD() & "/" & arguments.path;
		} else if ( fileExists( expandPath( arguments.path ) ) ){
			// try expanding the path
			arguments.path = expandPath( arguments.path );
		} else {
			if ( directoryExists( arguments.path ) ){
				// directory exists
			} else if ( directoryExists( getCWD() & "/" & arguments.path ) ){
				// try adding the directory to the current working directory if the directory doesn't exist
				arguments.path = getCWD() & "/" & arguments.path;
			} else if ( directoryExists( expandPath( arguments.path ) ) ){
				// try expanding the path
				arguments.path = expandPath( arguments.path );
			} else {
				print.line( arguments.path & " is not a valid file or directory" );
				return;
			}

			print.line( "Removing trailing spaces from " & arguments.path & "..." );

			variables.excludeFolders = getExcludeFolders();
			var fileList = directoryList( arguments.path, true, "path" );

			for ( var i in fileList ){
				var fileInfo = getFileInfo( i );
				// only process files
				if ( fileInfo.type == "file" &&
				    !isExcludedDirectory( i ) &&
					!variables.excludeExtensions.contains( listLast( i, "." ) ) ){
					removeTrailingSpaces( i );
				}
			}

			return;
		}

		print.line( "Removing trailing spaces from " & arguments.path & "..." );
		removeTrailingSpaces( arguments.path );
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

	private function getLineEndings( data ){
		if ( arguments.data.len() > 0 ){
			if ( arguments.data[1].find( chr( 13 ) & chr( 10 ) ) != 0 ){
				return chr( 13 ) & chr( 10 );
			} else if ( arguments.data[1].find( chr( 13 ) ) != 0 ){
				return chr( 13 );
			}
		}

		return chr( 10 );
	}

	private function isExcludedDirectory( file ){
		// convert all backslashes to forward-slashes
		var f = arguments.file.replace( "\", "/" );

		for ( var i in variables.excludeFolders ){
			// check if file exists in the exclude directory
			if ( f.find( "/" & i & "/" ) || f.startsWith( i )){
				return true;
			}
		}
		// file isn't in any of the exclude directories
		return false;
	}

	private function getExcludeFolders(){
		return [ '.git' ];
	}

	private function getExcludeExtensions(){
		return [
			'.eot',
			'.gif',
			'.ico',
			'.jar',
			'.jpeg',
			'.jpg',
			'.otf',
			'.pdf',
			'.png',
			'.svg',
			'.ttf',
			'.woff',
			'.woff2',
			'.zip',
		];
	}
}
