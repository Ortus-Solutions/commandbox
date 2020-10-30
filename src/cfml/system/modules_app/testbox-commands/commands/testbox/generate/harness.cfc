/**
 * Create a new TestBox test harness for an application. The test harness will be created in a directory called tests.
 * .
 * You can run it from the root of your application.
 * {code:bash}
 * testbox create harness
 * {code}
 * .
 * Or pass the base directory of your application as a parameter
 * {code:bash}
 * testbox create harness C:\myApp
 * {code}
 */
component {

	/**
	 * @directory The base directory to create your test harness
	 */
	function run( string directory = getCWD() ){
		// This will make each directory canonical and absolute
		arguments.directory = resolvePath( arguments.directory & "/tests" );

		// Validate directory
		if ( !directoryExists( arguments.directory ) ) {
			directoryCreate( arguments.directory );

			// Copy template
			directoryCopy(
				"/testbox-commands/templates/testbox/test-harness/",
				arguments.directory,
				true
			);

			// Print the results to the console
			print.greenLine( "Created " & arguments.directory );
		} else {
			error( "Directory #arguments.directory# already exists!" );
		}
	}

}
