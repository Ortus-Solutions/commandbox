 /**
 * Looks up the user associated with your current ForgeBox API Token
 * .
 * {code:bash}
 * forgebox whoami
 * {code}
 **/
component {

	property name="configService" inject="configService";
	property name="endpointService" inject="endpointService";

	/**
	* @endpointName  Name of custom forgebox endpoint to use
	* @endpointName.optionsUDF endpointNameComplete
	**/
	function run( string endpointName ){
		try {
			
			endpointName = endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );
			
			try {		
				var oEndpoint = endpointService.getEndpoint( endpointName );
			} catch( EndpointNotFound var e ) {
				error( e.message, e.detail ?: '' );
			}
			
			var forgebox = oEndpoint.getForgebox();
			var APIToken = oEndpoint.getAPIToken();
			
			if( !len( APIToken ) ) {
				if( endpointName == 'forgebox' ) {
					error( 'You don''t have a Forgebox API token set.', 'Use "forgebox login" to authenticate as a user.' );	
				} else {
					error( 'You don''t have a Forgebox API token set.', 'Use "forgebox login endpointName=#endpointName#" to authenticate as a user.' );					
				}
			}
			userData = forgebox.whoami( APIToken );

			print.boldLine( '#userData.fname# #userData.lname# (#userData.username#)' )
				.line( userData.email );

		} catch( forgebox var e ) {
			// This can include "expected" errors such as "Email already in use"
			error( e.message, e.detail );
		}
	}
	
	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}

}
