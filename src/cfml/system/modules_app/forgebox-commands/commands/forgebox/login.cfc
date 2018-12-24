/**
 * Authenticates a user with the ForgeBox endpoint.  This command is a passthrough for the generic "endpoint login" command.
 * .
 * {code:bash}
 * forgebox login
 * {code}
 **/
component {
	property name="configService" inject="configService";
	property name="endpointService" inject="endpointService";
	
	/**
	* @username.hint Username for this user
	* @password.hint Password for this user
	* @endpointName  Name of custom forgebox endpoint to use
	* @endpointName.optionsUDF endpointNameComplete
	**/
	function run(
		string username='',
		string password='',
		string endpointName
	){

		endpointName = endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );
		try {		
			var oEndpoint = endpointService.getEndpoint( endpointName );
		} catch( EndpointNotFound var e ) {
			error( e.message, e.detail ?: '' );
		}

		var endpointURL = oEndpoint.getForgeBox().getEndpointURL();
		
		// Ask for username if not passed
		if( !len( arguments.username ) ) {

			// Info for ForgeBox
			print.line()
				.line( "Login with your ForgeBox ID to publish and manage packages in ForgeBox. ")
				.line( "If you don't have a ForgeBox ID, head over to #endpointURL# to create one or just use the" )
				.boldRed( " forgebox register ")
				.line( "command to register a new account.")
				.line()
				.toConsole();

            arguments.username = ask( 'Enter your username: ' );
        }

   		// Ask for password if not passed
        if( !len( arguments.password ) ) {
            arguments.password = ask( 'Enter your password: ', '*' );
        }

		// Message user since there can be a couple-second delay here
		print.line()
			.yellowLine( 'Contacting ForgeBox...' )
			.toConsole();

		// Defer to the generic command
		command( 'endpoint login' )
			.params( argumentCollection=arguments )
			.run();

	}
	
	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}

}
