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

		// This will make each directory canonical and absolute
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );

		if( !directoryExists( arguments.directory ) ) {
			return error( "#arguments.directory#: No such file or directory" );
		}

		return shell.cd( arguments.directory );
	}


}