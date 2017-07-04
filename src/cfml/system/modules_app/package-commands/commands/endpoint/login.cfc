/**
 * Authenticates a user with an endpoint.  The endpoint must be interactive.
 * .
 * {code:bash}
 * endpoint login
 * {code}
 **/
component {

	property name="EndpointService" inject="EndpointService";

	/**
	* @endpointName.hint Name of the endpoint to log in to
	* @username.hint Username for this user
	* @password.hint Password for this user
	**/
	function run(
		required string endpointName,
		required string username,
		required string password ) {

		try {

			endpointService.loginEndpointUser( argumentCollection=arguments );

		} catch( endpointException var e ) {
			// This can include "expected" errors such as "Email already in use"
			error( e.message, e.detail );
		}

		print.greenLine( 'User [#arguments.username#] authenticated successfully with [#arguments.endpointName#]' );
	}

}