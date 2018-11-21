 /**
 * Switch APIKey in use based on username.  If no API Key is stored, prompt to authenticate
 * .
 * {code:bash}
 * forgebox use username
 * {code}
 * .
 * To skip interactivity, use the skipLogin flag and you won't be asked to log if the username provided isn't authenticated
 * {code:bash}
 * forgebox use username --skipLogin
 * {code}
 **/
component {

	property name="forgeBox" inject="ForgeBox";
	property name="configService" inject="ConfigService";

	/**
	* @username The ForgeBox username to switch to.
	* @skipLogin If username isn't authenticated, return an error instead of prompting with login
	**/
	function run( required string username, boolean skipLogin=false ){

		var tokens = configService.getSetting( 'endpoints.forgebox.tokens', {} );
		if( !len( arguments.username ) ) {
			error( 'Please provide a ForgeBox username to use.' );
		}

		// If this username exists
		if( tokens.keyExists( arguments.username ) ) {
			// Set the active token
			configService.setSetting( 'endpoints.forgebox.APIToken', tokens[ arguments.username ] );
			print.greenLine( 'Active Forgebox user set to [#arguments.username#]' );
		} else if( !skipLogin ) {
			// Otherwise, prompt them to login
			command( 'forgebox login' )
				.params( arguments.username )
				.run();
		} else {
			error( 'Username [#arguments.username#] isn''t authenticated.  Please use "forgebox login".' );
		}
	}

}
