/**
 * Watch the files in a directory and run the default TestBox suite on any file change.
 *
 * {code}
 * testbox watch
 * {code}
 * 
 * In order for this command to work, you need to have started your server and configured the 
 * URL to the test runner in your box.json.
 *
 * {code}
 * server set testbox.runner=http://localhost:8080/tests/runner.cfm
 * server start
 * testbox watch
 * {code}
 * 
 * If you need more control over what tests run and their output, you can set additional options in your box.json
 * which will be picked up automatically by "testbox run" whe it fires.
 *
 * {code}
 * server set testbox.verbose=false
 * server set testbox.labels=foo
 * server set testbox.testSuites=bar
 * {code}
 * 
 * This command will run in the foreground until you stop it.  When you are ready to shut down the watcher, press Ctrl+C.
 *
 **/
component {

	// DI
	property name="packageService" 	inject="PackageService";

	variables.WATCH_DELAY 	= 500;
	variables.PATHS 		= "**.cfc";
	
	/**
	 * @paths Command delimeted list of file globbing paths to watch relative to "directory", defaults to **.cfc
	 * @delay How may miliseconds to wait before polling for changes, defaults to 500 ms
	 * @directory The directory to watch for changes. "testbox run" is executed in this folder as well.
	 **/
	function run(
		string paths,  
	 	number delay,
	 	string directory=''
	) {
		
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
		
		// Get testbox options from package descriptor
		var boxOptions = packageService.readPackageDescriptor( getCWD() ).testbox;

		var getOptionsWatchers = function(){
			// Return to List
			if( boxOptions.keyExists( "watchers" ) ){
				if( isArray( boxOptions.watchers ) ){
					return boxOptions.watchers.toList();
				}
				return boxOptions.watchers;
			}
			// should return null if not found
		}
		
		// Determine watching patterns, either from arguments or boxoptions or defaults
		var globbingPaths = arguments.paths ?: getOptionsWatchers() ?: variables.PATHS;

		// Tabula rasa
		command( 'cls' ).run();
		
		// Start watcher
		watch()
			.paths( globbingPaths.listToArray() )
			.inDirectory( directory )
			.withDelay( arguments.delay ?: boxOptions.watchDelay ?: variables.WATCH_DELAY )
			.onChange( function() {
				
				// Clear the screen
				command( 'cls' )
					.run();
					
				// Run the tests in the target directory
				command( 'testbox run' )
					.inWorkingDirectory( directory )
					.run();
										
			} )
			.start();
	}

}