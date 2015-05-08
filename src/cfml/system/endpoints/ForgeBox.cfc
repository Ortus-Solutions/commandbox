/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the ForgeBox endpoint.  I wrap CFML's coolest package repository
*/
component  implements="IEndpointInteractive" accessors="true" singleton {
	property name="namePrefixs" type="string";
	
	function init() {
		setNamePefixes( 'forgebox' );
	}
	
	public string function resolve(required string ID) {

	}

	public function createUser(required string userName,required string password) {

	}
	
	public string function login(required string userName,required string password) {

	}
	
	public function publish(required string path) {

	}

}