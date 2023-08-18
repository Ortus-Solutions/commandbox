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

	property name="configService" 		inject="configService";
	property name="endpointService" 	inject="endpointService";
	property name='interceptorService'	inject='interceptorService';

	/**
	* @username The ForgeBox username to switch to.
	* @username.optionsUDF usernameComplete
	* @skipLogin Return an error instead of prompting with login if username isn't authenticated,
	* @endpointName  Name of custom forgebox endpoint to use
	* @endpointName.optionsUDF endpointNameComplete
	**/
	function run(
		required string username,
		boolean skipLogin=false,
		string endpointName ){

		endpointName = endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );

		try {
			var oEndpoint = endpointService.getEndpoint( endpointName );
		} catch( EndpointNotFound var e ) {
			error( e.message, e.detail ?: '' );
		}

		var APIToken = oEndpoint.getAPIToken();

		var tokens = oEndpoint.getAPITokens();

		if( !len( arguments.username ) ) {
			error( 'Please provide a ForgeBox username to use.' );
		}

		// If this username exists
		if( tokens.keyExists( arguments.username ) ) {
			// Set the active token
			oEndpoint.setDefaultAPIToken( tokens[ arguments.username ] );
			print.greenLine( 'Active Forgebox user set to [#arguments.username#]' );

			interceptorService.announceInterception( 'onEndpointLogin', { endpointName=endpointName, username=username, endpoint=oEndpoint, APIToken=APIToken } );

		} else if( !skipLogin ) {
			// Otherwise, prompt them to login
			command( 'forgebox login' )
				.params( username=arguments.username, endpointName=endpointName )
				.run();
		} else {
			error( 'Username [#arguments.username#] isn''t authenticated.  Please use "forgebox login".' );
		}

	}

	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}

	function usernameComplete( paramSoFar, passedNamedParameters ) {

		endpointName = arguments.passedNamedParameters.endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );

		try {
			var oEndpoint = endpointService.getEndpoint( endpointName );
			var tokens = oEndpoint.getAPITokens();
			return tokens.keyArray();
		} catch( EndpointNotFound var e ) {
		}


	}


}
