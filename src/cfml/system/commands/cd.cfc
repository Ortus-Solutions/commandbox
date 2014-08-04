/**
 * Change the current working directory of the shell.
 * .
 * Create a copy of a directory
 * {code}
 * cd tests/
 * {code}
 * .
 * As with any file and folder parameters, you can traverse "up" a directory.
 * {code}
 * cd ../../tests
 * {code} 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

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