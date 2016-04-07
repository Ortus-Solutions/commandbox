/**
 * Authenticates a user with the ForgeBox endpoint.  This command is a passthrough for the generic "endpoint login" command.
 * .
 * {code:bash}
 * forgebox login
 * {code}
 **/
component {
	
	/**  
	* @username.hint Username for this user
	* @password.hint Password for this user
	**/
	function run( 
		required string username,
		required string password ) {
	
		// Default the endpointName
		arguments.endpointName = 'forgebox';
		
		// Defer to the generic command
		command( 'endpoint login' )
			.params( argumentCollection=arguments )
			.run();
			
	}

}