/**
 * Registers a new user with an endpoint.  The endpoint must be interactive.
 * .
 * {code:bash}
 * endpoint register 
 * {code}
 **/
component {
	
	property name="EndpointService" inject="EndpointService";	
	
	/**  
	* @endpointName.hint Name of the endpoint for which to create the user
	* @username.hint Username for this user
	* @password.hint Password for this user
	* @email.hint E-mail address
	* @firstName.hint First name of the user
	* @lastName.hint Last name of the user
	**/
	function run( 
		required string endpointName,
		required string username,
		required string password,
		required string email,
		required string firstName,
		required string lastName ) {
			
		try {
			
			endpointService.createEndpointUser( argumentCollection=arguments );
			
		} catch( endpointException var e ) {
			// This can include "expected" errors such as "Email already in use"
			error( e.message, e.detail );
		}
		
		print.greenLine( 'User [#arguments.username#] created successfully in [#arguments.endpointName#]' );		
	}

}