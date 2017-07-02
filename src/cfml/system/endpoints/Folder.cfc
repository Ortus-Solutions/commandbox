/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the folder endpoint.  I get packages from a local folder.
*/
component accessors="true" implements="IEndpoint" singleton {
		
	// DI
	property name="packageService"	inject="packageService";
	property name="semanticVersion"	inject="semanticVersion@semver";
	
	// Properties
	property name="namePrefixes" type="string";
	
	function init() {
		setNamePrefixes( 'folder' );
		return this;
	}
		
	public string function resolvePackage( required string package, boolean verbose=false ) {
	
		package = packageService.findPackageRoot( package );
		
		return package;

	}

	/**
	* Determines the name of a package based on its ID if there is no box.json
	*/
	public function getDefaultName( required string package ) {
		return listLast( arguments.package, '/\' );
	}

	public function getUpdate( required string package, required string version, boolean verbose=false ) {
		var result = {
			isOutdated = false,
			version = 'unknown'
		};
		
		if( directoryExists( arguments.package ) ) {
			var boxJSON = packageService.readPackageDescriptor( arguments.package );
			result.isOutdated = semanticVersion.isNew( current=arguments.version, target=boxJSON.version );
			result.version = boxJSON.version;
		}
		
		return result;
	}
	
}