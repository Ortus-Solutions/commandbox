/**
 * Registers a new user with the Forgebox endpoint.  This command is a passthrough for the generic "endpoint register" command.
 * .
 * {code:bash}
 * forgebox register
 * {code}
 **/
component {

	/**
	* @username.hint Username for this user
	* @password.hint Password for this user
	* @email.hint E-mail address
	* @firstName.hint First name of the user
	* @lastName.hint Last name of the user
	 **/
	function run(
		required string username,
		required string password,
		required string email,
		required string firstName,
		required string lastName ) {

		// Default the endpointName
		arguments.endpointName = 'forgebox';

		// Defer to the generic command
		command( 'endpoint register' )
			.params( argumentCollection=arguments )
			.run();

	}

}