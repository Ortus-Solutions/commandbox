/**
 * Un-authenticates a user from the ForgeBox endpoint.  This command is a passthrough for the generic "endpoint logout" command.
 * .
 * Logout a single user
 * {code:bash}
 * forgebox logout username
 * {code}
 * .
 * Logout ALL users
 * {code:bash}
 * forgebox logout
 * {code}
 **/
component {
	property name="configService" inject="configService";
	property name="endpointService" inject="endpointService";
	
	/**
	* @username.hint Username for this user
	* @endpointName  Name of custom forgebox endpoint to use
	* @endpointName.optionsUDF endpointNameComplete
	**/
	function run(
		string username='',
		string endpointName
	){

		endpointName = endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );

		// Defer to the generic command
		command( 'endpoint logout' )
			.params( argumentCollection=arguments )
			.run();
	}
	
	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}

}
