/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the RIAForge endpoint.  I get packages from RIAForge.org based on their slug.
* install riaforge:projectURLSlug
*/
component accessors="true" implements="IEndpoint" singleton {
		
	// DI
	property name="consoleLogger"			inject="logbox:logger:console";
	property name="HTTPEndpoint"			inject="commandbox.system.endpoints.HTTP";
	
	// Properties
	property name="namePrefixes" type="string";
	
	function init() {
		setNamePrefixes( 'RIAForge' );
		return this;
	}
		
	public string function resolvePackage( required string package, boolean verbose=false ) {
		// Defer to HTTP endpoint
		// This assumes that the download URL will point to a zip file.  If not, all bets are off.
		return HTTPEndpoint.resolvePackage( '//#arguments.package#.riaforge.org/index.cfm?event=action.download&doit=true', arguments.verbose );
	}

	public function getDefaultName( required string package ) {
		return reReplaceNoCase( arguments.package, '[^a-zA-Z0-9]', '', 'all' );
	}

	public function getUpdate( required string package, required string version, boolean verbose=false ) {
		var result = {
			isOutdated = true,
			version = 'unknown'
		};
		
		return result;
	}

}