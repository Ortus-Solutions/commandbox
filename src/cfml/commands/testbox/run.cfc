/**
 * This command executes TestBox runners via HTTP/S
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	// DI
	property name="cr" 				inject="cr";
	property name="packageService" 	inject="PackageService";

	/**
	* Ability to execute TestBox tests
	* @runner.hint The URL or shortname of the runner to use, if it uses a short name we look in your box.json
	* @bundles.hint The path or list of paths of the spec bundle CFCs to run and test
	* @directory.hint The directory mapping to test: directory = the path to the directory using dot notation (myapp.testing.specs)
	* @recurse.hint Recurse the directory mapping or not, by default it does
	* @reporter.hint The type of reporter to use for the results, by default is uses our 'simple' report. You can pass in a core reporter string type or a class path to the reporter to use.
	* @reporterOptions.hint A JSON struct literal of options to pass into the reporter
	* @labels.hint The list of labels that a suite or spec must have in order to execute.
	* @options.hint A JSON struct literal of configuration options that are optionally used to configure a runner.
	* @testBundles.hint A list or array of bundle names that are the ones that will be executed ONLY!
	* @testSuites.hint A list of suite names that are the ones that will be executed ONLY!
	* @testSpecs.hint A list of test names that are the ones that will be executed ONLY!
	* @outputFile.hint We will store the results in this output file as well as presenting it to you.
	**/
	function run(
		string runner="",
		string bundles,
		string directory,
		boolean recurse=true,
		string reporter="text",
		string reporterOptions,
		string labels,
		string options,
		string testBundles,
		string testSuites,
		string testSpecs,
		string outputFile
	){
		
		// get the box.json from the project, else empty if not found.
		var boxData = packageService.readPackageDescriptor( shell.pwd() );

		// if we have boxdata then try to discover runner from it.
		if( !structIsEmpty( boxData ) ){
			// check for testbox data and runner key
			if( structKeyExists( boxData, "testbox" ) and structKeyExists( boxData.testbox, "runner" ) ){
				// if we have an empty runner, discover runner from box data 
				if( !len( arguments.runner ) ){
					// simple runner?
					if( isSimpleValue( boxData.testbox.runner ) ){
						arguments.runner = boxData.testbox.runner;
					}
					// array of runners
					else {
						// get the first definition in the list to use
						var runnerDef = boxdata.testbox.runner[ 1 ];
						for( var thisKey in runnerDef ){
							arguments.runner = runnerDef[ thisKey ];
							break;
						}
					}
				} 
				// else we do have a passed runner, let's see if it matches the runners defined.
				else if ( len( arguments.runner ) ){
					// only check if we have an array of struct definitions, else ignore.
					if( isArray( boxData.testbox.runner ) ){
						for( var thisRunner in boxData.testbox.runner ){

						}
					}
					arguments.runner = boxdata.testbox.runner[ arguments.runner ];
				}
				// else just use the passed runner as a URL

			}

			// We know need to build the params according to box.json
		}

		var testboxURL = arguments.runner & "?recurse=#arguments.recurse#&reporter=#arguments.reporter#";
		// Do we have bundles
		if( !isNull( arguments.bundles ) ){ testboxURL &= "&bundles=#arguments.bundles#"; }
		// Do we have directory
		if( !isNull( arguments.bundles ) ){ testboxURL &= "&directory=#arguments.directory#"; }
		// Do we have labels
		if( !isNull( arguments.labels ) ){ testboxURL &= "&labels=#arguments.labels#"; }
		// Do we have testBundles
		if( !isNull( arguments.testBundles ) ){ testboxURL &= "&testBundles=#arguments.testBundles#"; }
		// Do we have testSuites
		if( !isNull( arguments.testSuites ) ){ testboxURL &= "&labels=#arguments.testSuites#"; }
		// Do we have testSpecs
		if( !isNull( arguments.testSpecs ) ){ testboxURL &= "&labels=#arguments.testSpecs#"; }
		
		// Advice we are running
		print.boldCyanLine( "Executing tests via #testBoxURL#, please wait..." )
			.blinkingRed( "Please wait...")
			.printLine()
			.toConsole();

		// run it now baby!
		try{
			var results = new Http( url=testBoxURL ).send().getPrefix();
		} catch( any e ){
			log.error( "Error executing tests: #e.message# #e.detail#", e );
			return error( 'Error executing tests: #CR# #e.message##CR##e.detail#' );
		}

		// Do we have an output file
		if( !isNull( arguments.outputFile ) ){
			// Attach pwd location
			if( left( arguments.outputFile, 1 ) != "/" ){
				arguments.outputFile = shell.pwd() & "/" & arguments.outputFile;
			}
			// write it
			fileWrite( arguments.outputFile, results.fileContent );
			print.boldGreenLine( "Report written to #arguments.outputFile#!" );
		}

		// Print accordingly
		if( ( results.responseheader[ "x-testbox-totalFail" ]  ?: 0 ) eq 0 AND
			( results.responseheader[ "x-testbox-totalError" ] ?: 0 ) eq 0 ){
			// print OK report
			print.green( " " & results.filecontent );
		} else if( results.responseheader[ "x-testbox-totalFail" ] gt 0 ){
			// print Failure report
			print.yellow( " " & results.filecontent );
		} else if( results.responseheader[ "x-testbox-totalError" ] gt 0 ){
			// print Failure report
			print.boldRed( " " & results.filecontent );
		}
		
	}

}