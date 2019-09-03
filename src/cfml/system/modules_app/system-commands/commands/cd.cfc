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
 **/
component {

	/**
	 * @directory.hint The directory to change to
	 **/
	function run( directory="" )  {

		if (arguments.directory == '-') {
			arguments.directory = systemSettings.getSystemSetting( 'OLDPWD' );
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
