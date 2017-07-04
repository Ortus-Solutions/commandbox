/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the github endpoint. I install 'shortcut' packages listed as "user/repo[#committ-ish]"
*/
component accessors="true" implements="IEndpoint" extends="commandbox.system.endpoints.Git" singleton {

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'github' );
		return this;
	}

	public string function resolvePackage( required string package, boolean verbose=false ) {
		if( listLen( arguments.package, '##' ) == 2 ) {
			return super.resolvePackage( '//github.com/' & listFirst( arguments.package, '##' ) & '.git' & '##' & listLast( arguments.package, '##' ), arguments.verbose );
		} else {
			return super.resolvePackage( '//github.com/' & arguments.package & '.git', arguments.verbose );
		}
	}

	public function getDefaultName( required string package ) {
		// Remove committ-ish
		var baseURL = listFirst( arguments.package, '##' );

		// Find last segment of URL (may or may not be a repo name)
		return listLast( baseURL, '/' );
	}
}