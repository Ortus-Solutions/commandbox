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
	property name="packageService" 	inject="packageService";
	
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

}