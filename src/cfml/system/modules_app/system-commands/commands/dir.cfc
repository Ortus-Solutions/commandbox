/**
 * List the files and folders in a directory.  Defaults to current working directory
 * .
 * {code:bash}
 * dir samples/
 * {code}
 * .
 * File globbing patterns can be used to filter results. Can also be a list
 * .
 * {code:bash}
 * dir **.cfc,*.cfm
 * {code}
 * .
 * File globbing patterns can be used to exclude results. Can also be a list
 * .
 * {code:bash}
 * dir paths=modules excludePaths=**.md --recurse
 * {code}
 * .
 * Use the "recurse" parameter to show all nested files and folders.
 * .
 * {code:bash}
 * dir samples/ --recurse
 * {code}
 * .
 * Ordering results is in format of an ORDER BY SQL clause. Invalid sorts are ignored.
 * .
 * {code:bash}
 * dir samples "directory asc, name desc"
 * {code}
 *
 **/
component aliases="ls,ll,directory" {

	/**
	 * @paths The directory to list the contents of or a list of file Globbing path to filter on
	 * @excludePaths A list of file glob patterns to exclude
	 * @sort Sort columns and direction. name, directory, size, type, dateLastModified, attributes, mode
	 * @sort.options DateLastModified,Directory,Name,Size,Type,attributes,mode
	 * @recurse Include nested files and folders
	 * @simple Output only path names and nothing else.
	 * @full Output abolute file path, not just relative to current working directory
	 **/
	function run( Globber paths=globber( getCWD() ), sort='type, name', string excludePaths='', boolean recurse=false, boolean simple=false, boolean full=false )  {

		// Backwards compat for old parameter name
		if( arguments.keyExists( 'directory' ) && arguments.directory.len() ) {
			paths.setPattern( fileSystemUtil.resolvePath( arguments.directory ) );
		}

		// If the user gives us an existing directory foo, change it to the
		// glob pattern foo/* or foo/** if doing a recursive listing.
		paths.setPattern(
			paths.getPatternArray().map( (p) => {
				if( directoryExists( p ) ){
					return p & '*' & ( recurse ? '*' : '' );
				}
				return p;
			} )
		);

		excludePaths = excludePaths.listMap( (p) => {
			p = fileSystemUtil.resolvePath( p )
			if( directoryExists( p ) ){
				return p & '*' & ( recurse ? '*' : '' );
			}
			return p;
		} );

		var results = paths
			.setExcludePattern( excludePaths )
			.asQuery()
			.withSort( sort )
			.matches();

		for( var x=1; x lte results.recordcount; x++ ) {

			if( simple ) {

				print.line(
					cleanRecursiveDir( arguments.paths.getBaseDir(), results.directory[ x ] & '/', full )
					& results.name[ x ]
					& ( results.type[ x ] == "Dir" ? "/" : "" )
				);

				continue;
			}

			var printCommand = ( results.type[ x ] eq "File" ? "green" : "white" );

			print.text(
	//			results.type[ x ] & " " &
//				( results.type[ x ] eq "Dir" ? " " : "" ) & //padding
				dateTimeFormat( results.dateLastModified[ x ], "MMM dd,yyyy  HH:mm:ss" ) & "   " &

				results.attributes[ x ] & " " &
				( results.attributes[ x ].len() < 6 ? repeatString( ' ', 6-results.attributes[ x ].len() ) : '' ) &

				( results.type[ x ] eq "Dir" ? "    <DIR>" : renderFileSize( results.size[ x ] ) ) & "   "

			);

			colorPath(
				cleanRecursiveDir( arguments.paths.getBaseDir(), results.directory[ x ] & '/', full )
					& results.name[ x ]
					& ( results.type[ x ] == "Dir" ? "/" : ""
				),
				results.type[ x ]
			);

		}

		if( results.recordcount eq 0 ){
			print.orangeLine( "No files/directories found." );
		}
	}

	/**
	* Cleanup directory recursive nesting
	*/
	private function cleanRecursiveDir( required directory, required incoming, boolean full ){
		if( full ) {
			return incoming;
		}
		var prefix = ( replacenocase( fileSystemUtil.normalizeSlashes( arguments.incoming ), fileSystemUtil.normalizeSlashes( arguments.directory ), "" ) );
		return ( len( prefix ) ? reReplace( prefix, "^(/|\\)", "" ) : "" );
	}

	private function colorPath( name, type ){

		if( type == 'Dir' ) {
			print.BlueLine( name );
		} else {
			var ext = name.listLast( '.' );
			if( name.startsWith( '.' ) ) { ext = 'hidden'; }

			switch( ext ) {
				// Binary/exuctable
			    case "exe": case "jar": case "com": case "bat": case "msi": case "lar": case "lco": case "class": case "dll": case "war": case "eot": case "svg": case "ttf": case "woff": case "woff2":
					print.AquaLine( name );
			         break;
			    // Compressed
			    case "zip": case "tar": case "gz":
					print.Gold3Line( name );
			         break;
		        // Code
			    case "cfml": case "cfm": case "cfc": case "html": case "htm": case "js": case "css": case "java": case "boxr": case "sh": case "sql":
					print.CyanLine( name );
			         break;
		       // Images
			    case "gif": case "jpg": case "bmp": case "jpeg": case "png": case "ico":
					print.YellowLine( name );
			         break;
			    // Design/browser assets
			    case "js": case "css": case "less": case "sass":
					print.OliveLine( name );
			         break;
			    // Plain text/data
			    case "json": case "txt": case "properties": case "yml": case "yaml": case "xml": case "xsd": case "log": case "ini": case "conf":
					print.LimeLine( name );
			         break;
			    // Documents
			    case "pdf": case "doc": case "docx": case "xls": case "csv": case "md": case "ppt": case "pptx": case "xlsx": case "odp": case "ods": case "rtf":
					print.RedLine( name );
			         break;
			    // Hidden files
			    case "hidden":
					print.MaroonLine( name );
			         break;
			    default:
					print.Line( name );
			}

		}
	}

	/**
	* Returns file size in either b, kb, mb, gb, or tb
	*
	* @tpe File size to be rendered
	*/
	private function renderFileSize( required numeric size, string type='bytes' ) {

		local.newsize = ARGUMENTS.size;
		local.filetype = ARGUMENTS.type;
		do{
			local.newsize = (local.newsize / 1024);
			if(local.filetype IS 'bytes')local.filetype = 'KB';
			else if(local.filetype IS 'KB')local.filetype = 'MB';
			else if(local.filetype IS 'MB')local.filetype = 'GB';
			else if(local.filetype IS 'GB')local.filetype = 'TB';
		} while((local.newsize GT 1024) AND (local.filetype IS NOT 'TB'));

		return numberFormat( local.newsize, '9999.0' ) & ' ' & local.filetype;
	}

}
