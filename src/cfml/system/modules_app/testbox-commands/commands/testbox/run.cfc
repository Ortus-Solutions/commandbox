/**
* Executes TestBox runners via HTTP/S.  By default, the "testbox.runner" property will be read from your box.json.
* If the property is a string, it will be used directly as a URL.
* .
* {code:bash}
* testbox run
* {code}
* 
* If testbox.runner is an array of structs like so:
* .
* {code:bash}
* |  "testbox" : {
* |    "runner" : [
* |      {
* |        "server1" : "http://localhost/tests/runner.cfm",
* |        "server2" : "/tests/runner.cfm"
* |      }
* |    ]
* |  }
* {code}
* .
* You target a specific URL by name.
* .
* {code:bash}
* testbox run server1
* testbox run server2
* {code}
* .
* You can also specify the URL manually
* {code:bash}
* testbox run http://localhost:8080/tests/runner.cfm
* {code}
* .
* If you have a CommandBox server running in the current directory, you can specify a partial URL that starts with /
* {code:bash}
* testbox run /tests/runner.cfm
* {code}
* .
* You can set arbitrary URL options in our box.json like so
* {code:bash}
* package set testbox.options.opt1=value1
* package set testbox.options.opt2=value2
* {code}
* .
* You can set arbitrary URL options when you run the command like so
* {code:bash}
* testbox run options:opt1=value1 options:opt2=value2
* {code}
*
 **/
component {

	// DI
	property name="packageService" 	inject="PackageService";
	property name="testingService" 	inject="TestingService@testbox-commands";
	property name="CLIRenderer" 	inject="CLIRenderer@testbox-commands";
	property name="serverService" inject="ServerService";

	/**
	* Ability to execute TestBox tests
	* @runner      The URL or shortname of the runner to use, if it uses a short name we look in your box.json
	* @bundles     The path or list of paths of the spec bundle CFCs to run and test
	* @directory   The directory mapping to test: directory = the path to the directory using dot notation (myapp.testing.specs)
	* @recurse     Recurse the directory mapping or not, by default it does
	* @reporter    The type of reporter to use for the results, by default is uses our 'simple' report. You can pass in a core reporter string type or a class path to the reporter to use.
	* @labels      The list of labels that a suite or spec must have in order to execute.
	* @options     Add adhoc URL options to the runner as options:name=value options:name2=value2
	* @testBundles A list or array of bundle names that are the ones that will be executed ONLY!
	* @testSuites  A list of suite names that are the ones that will be executed ONLY!
	* @testSpecs   A list of test names that are the ones that will be executed ONLY!
	* @outputFile  We will store the results in this output file as well as presenting it to you.
	* @verbose Display extra details inlcuding passing and skipped tests.
	**/
	function run(
		string runner="",
		string bundles,
		string directory,
		boolean recurse,
		string reporter,
		string labels,
		struct options={},
		string testBundles,
		string testSuites,
		string testSpecs,
		string outputFile,
		boolean verbose
	){
		var runnerURL 	= '';

		// If a URL is passed, used it as an override
		if( left( arguments.runner, 4 ) == 'http' || left( arguments.runner, 1 ) == '/' ) {
			runnerURL = arguments.runner;
		// Otherwise, try to get one from box.json
		} else {
			runnerURL = testingService.getTestBoxRunner( getCWD(), arguments.runner );
			// Validate runner
			if( !len( runnerURL ) ){
				var boxJSON = packageService.readPackageDescriptor( getCWD() );
				var boxJSONRunner = boxJSON.testbox.runner ?: '';
				return error( '[#arguments.runner#] it not a valid runner in your box.json. Runners found are: #boxJSONRunner.toString()#' );
			}
		}

		// Resolve relative URI
		if( left( runnerURL, 1 ) == '/' ) {

			var serverDetails = serverService.resolveServerDetails( {} );
			var serverInfo = serverDetails.serverInfo;
	
			if( serverDetails.serverIsNew ){
				error( "The test runner we found [#runnerURL#] looks like partial URI, but we can't find any servers in this directory. Please give us a full URL." );
			} else {
				runnerURL = ( serverInfo.SSLEnable ? 'https://' : 'http://' ) & '#serverInfo.host#:#serverInfo.port##runnerURL#';	
			}			
		}

		// If we failed to find a URL, throw an error
		if( left( runnerURL, 4 ) != 'http' ) {
			return error( '[#runnerURL#] it not a valid URL, or does not match a runner slug in your box.json.' );
		}

		// Default runner builder and add ? if not detected
		var testboxURL = runnerURL;
		if( !find( "?", testboxURL ) ){
			testboxURL &= "?";
		}

		// Runner options overridable by arguments and box options
		var RUNNER_OPTIONS = {
			"reporter"	    : "json",
			"recurse"	    : true,
			"bundles"	    : "",
			"directory"	    : "",
			"labels"	    : "",
			"testBundles"	: "",
			"testSuites"	: "",
			"testSpecs" 	: "",
			"verbose"		: false
		};

		// Get testbox options from package descriptor
		var boxOptions 	= packageService.readPackageDescriptor( getCWD() ).testbox;
		// Build out runner options
		for( var thisOption in RUNNER_OPTIONS ){
			// Check argument overrides
			if( !isNull( arguments[ thisOption ] ) ){
				testboxURL &= "&#encodeForURL( thisOption )#=#encodeForURL( arguments[ thisOption ] )#";
			}
			// Check runtime options now
			else if( boxOptions.keyExists( thisOption ) && len( boxOptions[ thisOption ] ) ){
				if( isSimpleValue( boxOptions[ thisOption ] ) ) {
					testboxURL &= "&#encodeForURL( thisOption )#=#encodeForURL( boxOptions[ thisOption ] )#";	
				} else {
					print.yellowLine( 'Ignoring [testbox.#thisOption#] in your box.json since it''s not a string.  We can''t append it to a URL like that.' );
				}
			}
			// Defaults
			else if( len( RUNNER_OPTIONS[ thisOption ] ) ) {
				testboxURL &= "&#encodeForURL( thisOption )#=#encodeForURL( RUNNER_OPTIONS[ thisOption ] )#";
			}
		}
		
		// Get global URL options from box.json
		var extraOptions = boxOptions.options ?: {};
		// Add in command-specific options
		extraOptions.append( arguments.options );
		// Append to URL.
		for( var opt in extraOptions ) {
			testboxURL &= "&#encodeForURL( opt )#=#encodeForURL( extraOptions[ opt ] )#";
		}

		// Advise we are running
		print.boldCyanLine( "Executing tests via #testBoxURL# please wait..." )
			.toConsole();

		// run it now baby!
		try{
			// Throw on error means this command will fail if the actual test runner blows up-- possibly on a compilation issue.
			http url=testBoxURL throwonerror=true result='local.results';
		} catch( any e ){
			logger.error( "Error executing tests: #e.message# #e.detail#", e );
			return error( 'Error executing tests: #CR# #e.message##CR##e.detail##CR##local.results.fileContent ?: ''#' );
		}

		// Trim whitespaces
		results.fileContent = trim( results.fileContent );

		// Do we have an output file
		if( !isNull( arguments.outputFile ) ){
			// This will make each directory canonical and absolute
			arguments.outputFile = resolvePath( arguments.outputFile );
			
			
			var thisDir = getDirectoryFromPath( arguments.outputFile );
			if( !directoryExists( thisDir ) ) {
				directoryCreate( thisDir );
			}
			
			if( isJSON( results.fileContent ) ) {
				results.fileContent = formatterUtil.formatJSON( results.fileContent );	
			}
			
			// write it
			fileWrite( 
				arguments.outputFile, 
				results.fileContent
			);
			print.boldGreenLine( "===> Report written to #arguments.outputFile#!" );
		}

		// Default is to template our own output based on a JSON reponse
		if( RUNNER_OPTIONS.reporter == 'json' && isJSON( results.fileContent ) ) {

			var testData = deserializeJSON( results.fileContent );

			// If any tests failed or errored.
			if( testData.totalFail || testData.totalError ) {
				// Send back failing exit code to shell
				setExitCode( 1 );
			}

			// User our Renderer to publish the nice results
			CLIRenderer.render( print, testData, arguments.verbose ?: boxOptions.verbose ?: true );

		// For all other reporters, just dump out whatever we got from the server
		} else {

			results.fileContent = reReplace( results.fileContent, '[\r\n]+', CR, 'all' );

			// Print accordingly to results
			if( ( results.responseheader[ "x-testbox-totalFail" ]  ?: 0 ) eq 0 AND
				( results.responseheader[ "x-testbox-totalError" ] ?: 0 ) eq 0 ){
				// print OK report
				print.green( " " & results.filecontent );
			} else if( results.responseheader[ "x-testbox-totalFail" ] gt 0 ){
				// print Failure report
				setExitCode( 1 );
				print.yellow( " " & results.filecontent );
			} else if( results.responseheader[ "x-testbox-totalError" ] gt 0 ){
				// print Failure report
				setExitCode( 1 );
				print.boldRed( " " & results.filecontent );
			}

		}

	}

}
