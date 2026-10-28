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
	private function secureCloneCommand( required any cloneCommand, string GitURL ) {
		// Our CFML transport callback attaches the MINA sshd session factory
		var transportCallback = createDynamicProxy(
			new commandbox.system.util.JGitSSHCallback(),
			[ 'org.eclipse.jgit.api.TransportConfigCallback' ]
		);
		cloneCommand.setTransportConfigCallback( transportCallback );
		return cloneCommand;
	}
}
