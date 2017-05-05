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
	
	/**
	 * @paths Command delimeted list of file globbing paths to watch relative to "directory".
	 * @delay How may miliseconds to wait before polling for changes
	 * @directory The directory to watch for changes. "testbox run" is executed in this folder as well.
	 **/
	function run(
		string paths='**.cfc',  
	 	number delay=500,
	 	string directory=''
	) {
		
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
		
		// Tabula rasa
		command( 'cls' ).run();
		
		// Start watcher
		watch()
			.paths( paths.listToArray() )
			.inDirectory( directory )
			.withDelay( delay )
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