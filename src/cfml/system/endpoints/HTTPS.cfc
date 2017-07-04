/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the HTTPS endpoint.  I get packages from an HTTPS URL.
*/
component accessors="true" implements="IEndpoint" extends="commandbox.system.endpoints.HTTP" singleton {

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'HTTPS' );
		return this;
	}

}