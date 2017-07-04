/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle working with TestBox
*/
component accessors="true" singleton {

	// DI
	property name="packageService" 	inject="PackageService";

	/**
	* Constructor
	*/
	function init(){
		return this;
	}

	/**
	* Gets a TestBox runner URL from box.json with an optional slug to look up.  If no slug is passed, the first runner will be used
	* @directory The directory that is the root of the package
	* @slug An optional runner slug to look for in the list of runners
	*/
	public function getTestBoxRunner( required string directory, string slug='' ) {
		// Get box.json, create empty if it doesn't exist
		var boxJSON 	= packageService.readPackageDescriptor( arguments.directory );
		// Get reference to appropriate depenency struct
		var runners 	= boxJSON.testbox.runner;
		var runnerURL 	= '';

		// If there is a slug and runners is an array, look it up
		if ( len( arguments.slug ) && isArray( runners ) ){
			for( var thisRunner in runners ){
				// Does the string passed in match the slug of this runner? If so, return it
				if( structKeyExists( thisRunner, arguments.slug ) ) {
					return thisRunner[ arguments.slug ];
				}
			}
			// If we got here, we could not find slug, advice back with an empty runner
			return '';
		}

		// Just get the first one we can find

		// simple runner?
		if( isSimpleValue( runners ) ){
			return runners;
		}

		// Array of runners?
		if( isArray( runners ) ) {
			// get the first definition in the list to use
			var firstRunner = runners[ 1 ];
			return firstRunner[ listFirst( structKeyList( firstRunner ) ) ];
		}

		// We failed to find anything
		return '';
	}

}