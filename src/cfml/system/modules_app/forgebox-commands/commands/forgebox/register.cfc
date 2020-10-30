/**
 * Registers a new user with the Forgebox endpoint.  This command is a passthrough for the generic "endpoint register" command.
 * .
 * {code:bash}
 * forgebox register
 * {code}
 **/
component {
	property name="configService" inject="configService";

	/**
	* @username.hint Username for this user
	* @password.hint Password for this user
	* @email.hint E-mail address
	* @firstName.hint First name of the user
	* @lastName.hint Last name of the user
	* @endpointName  Name of custom forgebox endpoint to use
	* @endpointName.optionsUDF endpointNameComplete
	 **/
	function run(
		required string username,
		required string password,
		required string email,
		required string firstName,
		required string lastName,
		string endpointName ) {
		
		endpointName = endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );

		// Defer to the generic command
		command( 'endpoint register' )
			.params( argumentCollection=arguments )
			.run();

	}
	
	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}

}
