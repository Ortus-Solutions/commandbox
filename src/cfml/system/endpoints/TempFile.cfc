/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I am a file endpoint that deletes the zip when finished
*/
component accessors="true" implements="IEndpoint" extends="commandbox.system.endpoints.File" singleton {

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'tempFile' );
		return this;
	}

	// Override
	function cleanUp( package ) {
		fileDelete( package );
	}

}
