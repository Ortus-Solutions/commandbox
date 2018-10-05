/**
 * Watch the files in a directory and run the default Coldbox reinit on any file change.
 *
 * {code}
 * coldbox watch-reinit
 * {code}
 *
 * In order for this command to work, you need to have started your server and configured the
 * URL to the test runner in your box.json.
 *
 * {code}
 * server start
 * coldbox watch-reinit
 * {code}
 *
 * If you need more control over what tests run and their output, you can set additional options in your box.json
 * which will be picked up automatically by "testbox run" when it fires.
 *
 * {code}
 * package set reinitWatchDelay=1000
 * package set reinitWatchPaths=["config/**.cfc","handler/**.cfc","models/**.cfc"]
 * {code}
 *
 * This command will run in the foreground until you stop it.  When you are ready to shut down the watcher, press Ctrl+C.
 *
 **/
component {

	// DI
	property name="packageService" 	inject="PackageService";

	variables.WATCH_DELAY 	= 500;
	variables.PATHS 		= "config/**.cfc,handlers/**.cfc,models/**.cfc";

	/**
	 * @paths Command delimited list of file globbing paths to watch relative to the working directory, defaults to **.cfc
	 * @delay How may milliseconds to wait before polling for changes, defaults to 500 ms
	 **/
	function run(
		string paths,
	 	number delay
	) {

		// Get watch options from package descriptor
		var boxOptions = packageService.readPackageDescriptor( getCWD() );

		var getOptionsWatchers = function(){
			// Return to List
			if( boxOptions.keyExists( "reinitWatchPaths" ) && boxOptions.reinitWatchPaths.len() ){
				return ( isArray( boxOptions.reinitWatchPaths ) ? boxOptions.reinitWatchPaths.toList() : boxOptions.reinitWatchPaths );
			}
			// should return null if not found
			return;
		}

		// Determine watching patterns, either from arguments or boxoptions or defaults
		var globbingPaths = arguments.paths ?: getOptionsWatchers() ?: variables.PATHS;
		// handle non numberic config and put a floor of 150ms
		var delayMs = max( val( arguments.delay ?: boxOptions.reinitWatchDelay ?: variables.WATCH_DELAY ), 150 );

		// Tabula rasa
		command( 'cls' ).run();

		// Start watcher
		watch()
			.paths( globbingPaths.listToArray() )
			.inDirectory( getCWD() )
			.withDelay( delayMs )
			.onChange( function( changeData ) {

				print.line( formatterUtil.formatJSON(changeData) ).toConsole();

				command( 'coldbox reinit' ).run();


			} )
			.start();
	}

}
