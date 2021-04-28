/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the git+https endpoint.
*/
component accessors="true" implements="IEndpoint" extends="commandbox.system.endpoints.Git" singleton {

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'git+https' );
		return this;
	}

	private function secureCloneCommand( required any cloneCommand, string GitURL ) {
		// Parse the URL parts
		jURL = createOBject( 'java', 'java.net.URL' ).init( GitURL );
		/*
			Check for a format like
			https://username@domain.com
			or
			https://username:password@domain.com
		*/
		if( !isNull( jURL.getUserInfo() ) && len( jURL.getUserInfo() ) ) {

			// Strip out the username:password part
			var userInfo = jURL.getUserInfo();

			var username = userInfo.listFirst( ':' );
			var password = '';
			if( userInfo.listLen( ':' ) > 1 ) {
				var password = userInfo.listRest( ':' );
			}

			// Add user/pass into credentials provider
			cloneCommand.setCredentialsProvider( createObject( 'java', 'org.eclipse.jgit.transport.UsernamePasswordCredentialsProvider' ).init( username, password ) );
		} else {
			/* Default to netrc file which looks for ~/.netrc and then ~/_netrc with the format:

				machine github.com
				login myUser
				password mypass

			*/
			cloneCommand.setCredentialsProvider( createObject( 'java', 'org.eclipse.jgit.transport.NetRCCredentialsProvider' ).init() );
		}

		return cloneCommand;
	}


}
