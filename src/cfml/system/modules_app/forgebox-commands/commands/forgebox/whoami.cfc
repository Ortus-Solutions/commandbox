 /**
 * Looks up the user associated with your current ForgeBox API Token
 * .
 * {code:bash}
 * forgebox whoami
 * {code}
 **/
component {

	property name="forgeBox" inject="ForgeBox";
	property name="configService" inject="ConfigService";

	/**
	*
	**/
	function run(){
		try {
			var APIToken = configService.getSetting( 'endpoints.forgebox.APIToken', '' );
			if( !len( APIToken ) ) {
				error( 'You don''t have a Forgebox API token set.', 'Use "forgebox login" to authenticate as a user.' );
			}
			userData = forgebox.whoami( APIToken );

			print.boldLine( '#userData.fname# #userData.lname# (#userData.username#)' )
				.line( userData.email );

		} catch( forgebox var e ) {
			// This can include "expected" errors such as "Email already in use"
			error( e.message, e.detail );
		}
	}

}