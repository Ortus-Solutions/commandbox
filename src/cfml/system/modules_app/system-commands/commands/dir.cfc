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
	function run( Globber directory=globber( getCWD() ), Boolean recurse=false )  {

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

			print.text(
	//			results.type[ x ] & " " &
//				( results.type[ x ] eq "Dir" ? " " : "" ) & //padding
				dateTimeFormat( results.dateLastModified[ x ], "MMM dd,yyyy  HH:mm:ss" ) & "   " &
				
				results.attributes[ x ] & " " &
				( results.attributes[ x ].len() < 6 ? repeatString( ' ', 6-results.attributes[ x ].len() ) : '' ) &
				
				( results.type[ x ] eq "Dir" ? "    <DIR>" : renderFileSize( results.size[ x ] ) ) & "   "
				
			);
			
			colorPath( 
				cleanRecursiveDir( 
					arguments.directory.getBaseDir(),
					results.directory[ x ]
					)
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
	private function cleanRecursiveDir( required directory, required incoming, type ){
		var prefix = ( replacenocase( expandPath( arguments.incoming ), expandPath( arguments.directory ), "" ) );
		return ( len( prefix ) ? reReplace( prefix, "^(/|\\)", "" ) & "/" : "" );		
	}
	
	private function colorPath( name, type ){
		
		if( type == 'Dir' ) {
			print.BlueLine( name );
		} else {
			var ext = name.listLast( '.' );
			if( name.startsWith( '.' ) ) { ext = 'hidden'; }
			
			switch( ext ) {
				// Binary/exuctable
			    case "exe": case "jar": case "com": case "bat": case "msi": case "zip": case "lar": case "lco": case "tar": case "class": case "dll": case "war":  case "eot":  case "svg":  case "ttf":  case "woff":  case "woff2": 
					print.AquaLine( name );
			         break;
		        // Code
			    case "cfml": case "cfm": case "cfc": case "html": case "htm":  case "js":  case "css":  case "java": case "boxr": case "sh": case "sql": 
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
			    case "json": case "txt": case "properties": case "yml": case "yaml": case "xml": case "xsd": case "log": case "ini": 
					print.LimeLine( name );
			         break;
			    // Documents
			    case "pdf": case "doc": case "docx": case "xls":  case "csv":  case "md": case "ppt": case "pptx": case "xlsx": case "odp": case "ods": case "rtf": 
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
