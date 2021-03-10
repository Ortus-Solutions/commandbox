/**
 * Returns a passing (0) or failing (1) exit code whether the path exists.  Command outputs nothing.
 * .
 * {code:bash}
 * pathExists box.json && package show
 * {code}
 * .
 * You can specify if the path needs to be a file or a folder.
 * .
 * {code:bash}
 * pathExists --file server.json && server show
 * pathExists --directory foo || mkdir foo
 * {code}
**/
component {

	/**
	* @thePath The path to check
	* @file Validate that the path is a file
	* @directory Validate that the path is a directory
	**/
	function run( string thePath='', boolean file=false, boolean directory=false )  {

		// if nothing is passed, then yeah... I dunno.
		if( !thePath.len() ) {
			error( 'Path not provided!' );
		}

		thepath = resolvePath( thepath );

		// Must be a file
		if( file ) {
			if( !fileExists( thePath ) ) {
				setExitCode( 1 );
			}
		// Must be a directory
		} else if( directory ) {
			if( !directoryExists( thePath ) ) {
				setExitCode( 1 );
			}
		// Can be file or directory
		} else if( !fileExists( thePath ) && !directoryExists( thepath ) ) {
			setExitCode( 1 );
		}

	}


}
