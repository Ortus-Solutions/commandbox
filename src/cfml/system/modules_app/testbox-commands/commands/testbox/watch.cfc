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
 * package set testbox.runner=http://localhost:8080/tests/runner.cfm
 * server start
 * testbox watch
 * {code}
 *
 * If you need more control over what tests run and their output, you can set additional options in your box.json
 * which will be picked up automatically by "testbox run" when it fires.
 *
 * {code}
 * package set testbox.verbose=false
 * package set testbox.labels=foo
 * package set testbox.testSuites=bar
 * package set testbox.watchDelay=1000
 * package set testbox.watchPaths=/models/**.cfc
 * {code}
 *
 * This command will run in the foreground until you stop it.  When you are ready to shut down the watcher, press Ctrl+C.
 *
 **/
component {

	// DI
	property name="packageService" inject="PackageService";

	variables.WATCH_DELAY = 500;
	variables.PATHS       = "**.cfc";

	/**
	 * @paths 		Command delimited list of file globbing paths to watch relative to the working directory, defaults to **.cfc
	 * @delay 		How may milliseconds to wait before polling for changes, defaults to 500 ms
	 * @directory   The directory mapping to test: directory = the path to the directory using dot notation (myapp.testing.specs)
	 * @bundles     The path or list of paths of the spec bundle CFCs to run and test
	 * @labels      The list of labels that a suite or spec must have in order to execute.
	 * @verbose     Display extra details including passing and skipped tests.
	 * @recurse     Recurse the directory mapping or not, by default it does
	 * @reporter    The type of reporter to use for the results, by default is uses our 'simple' report. You can pass in a core reporter string type or a class path to the reporter to use.
	 * @options     Add adhoc URL options to the runner as options:name=value options:name2=value2
	 * @testBundles A list or array of bundle names that are the ones that will be executed ONLY!
	 * @testSuites  A list of suite names that are the ones that will be executed ONLY!
	 * @testSpecs   A list of test names that are the ones that will be executed ONLY!
	 **/
	function run(
		string paths,
		number delay,
		directory,
		bundles,
		labels,
		boolean verbose,
		boolean recurse,
		string reporter,
		struct options={},
		string testBundles,
		string testSuites,
		string testSpecs
	){
		// Get testbox options from package descriptor
		var boxOptions = variables.packageService.readPackageDescriptor( getCWD() ).testbox;

		var getOptionsWatchers = function(){
			// Return to List
			if ( boxOptions.keyExists( "watchPaths" ) && boxOptions.watchPaths.len() ) {
				return ( isArray( boxOptions.watchPaths ) ? boxOptions.watchPaths.toList() : boxOptions.watchPaths );
			}
			// should return null if not found
			return;
		}

		// Determine watching patterns, either from arguments or boxoptions or defaults
		var globbingPaths = arguments.paths ?: getOptionsWatchers() ?: variables.PATHS;
		// handle non numeric config and put a floor of 150ms
		var delayMs       = max( val( arguments.delay ?: boxOptions.watchDelay ?: variables.WATCH_DELAY ), 150 );

		// Tabula rasa
		command( "cls" ).run();

		// Start watcher with passed args only.
		var testArgs = arguments.filter( (k,v) => !isNull( v ) );
		watch()
			.paths( globbingPaths.listToArray() )
			.inDirectory( getCWD() )
			.withDelay( delayMs )
			.onChange( function(){
				// Clear the screen
				command( "cls" ).run();

				// Ignore failing tests, don't stop the watcher
				try {
					// Run the tests in the target directory
					command( "testbox run" )
						.params( argumentCollection = testArgs )
						.inWorkingDirectory( getCWD() )
						.run();
				} catch ( commandException var  e ) {
					// Log something, just in case we need to instead of empty console
					print.boldRedLine( left( e.message, 3000 ) ).toConsole();
				}
			} )
			.start();
	}

}
