/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the HTTP endpoint.  I get packages from an HTTP URL.
*/
component accessors=true implements="IEndpoint" singleton extends="commandbox.system.endpoints.HTTP_Cached" {

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'HTTPS+cached' );
		return this;
	}

}
