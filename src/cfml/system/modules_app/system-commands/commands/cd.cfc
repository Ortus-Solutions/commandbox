/**
 * Change the current working directory of the shell.
 * .
 * Switch into a directory
 * {code:bash}
 * cd tests/
 * {code}
 * .
 * As with any file and folder parameters, you can traverse "up" a directory.
 * {code:bash}
 * cd ../../tests
 * {code}
 * .
 * Another shortcut for going up a directoy is to add additional dots for each folder.
 * {code:bash}
 * cd ... => cd ../../ // back 2 directory
 * cd .... => cd ../../../ // back 3 directory
 * cd ..... // and so on...
 * {code}
 *
 **/
component {

	/**
	 * @directory.hint The directory to change to
	 **/
	function run( directory="" )  {

		if (arguments.directory == '-') {
			arguments.directory = systemSettings.getSystemSetting( 'OLDPWD', shell.pwd() );
		}

		// Shorthand expantion for going back muliple directories eg. "..." - expand mulitple dots "." to a "../"
		if( reMatch("^\.{2,}$", directory).len() ){
			arguments.directory = ( replace( Left( arguments.directory, len(arguments.directory) - 1 ), '.', '../', 'All' ) );
		}

		// This will make each directory canonical and absolute
		arguments.directory = resolvePath( arguments.directory );

		if( !directoryExists( arguments.directory ) ) {

			// Add a friendly check for someone trying to CD into the root of a UNC network share
			if( arguments.directory.reFind( '^\\\\[^\\/]*[\\/]?$' ) ) {
				print.boldRedLine( 'The root path of a Windows UNC network path cannot be listed or CD''d into.' )
					.boldRedLine( 'Try Changing into a shared folder like [#arguments.directory.listAppend( 'shareName', '/' )#]' );
			}

			return error( "#arguments.directory#: No such file or directory" );
		}

		systemSettings.setSystemSetting( 'OLDPWD', shell.pwd(), true );
		return shell.cd( arguments.directory );
	}


}
