/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the git+ssh endpoint.
*/
component accessors="true" implements="IEndpoint" extends="commandbox.system.endpoints.Git" singleton {
			
	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'git+ssh' );
		return this;
	}
	
	// Set SSH listener
	private function secureCloneCommand( required any cloneCommand ) {
		// This is our custom SSH callback
		var SSHCallback = createObject( 'java', 'com.ortussolutions.commandbox.jgit.SSHCallback' ).init(); 
		cloneCommand.setTransportConfigCallback( SSHCallback );
		return cloneCommand;
	}
}