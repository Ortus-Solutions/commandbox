/**
 * This command executes TestBox runners via HTTP/S
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
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
	**/
	function run(
		string runner="",
		string bundles,
		string directory,
		boolean recurse=true,
		string reporter="text",
		string reporterOptions="{}",
		string labels="",
		string options,
		string testBundles="",
		string testSuites="",
		string testSpecs=""
	){
		
		// get the box.json from the project, else empty if not found.
		var boxData = boxService.getBoxData( shell.pwd() );
		
		// if we have boxdata then try to discover runner from it.
		if( structCount( boxData ) ){
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
						for( var thisRunner in boxData.testbox.runner )
					}
					arguments.runner = boxdata.testbox.runner[ arguments.runner ];
				}
				// else just use the passed runner as a URL

			}
		}


		
	}

}