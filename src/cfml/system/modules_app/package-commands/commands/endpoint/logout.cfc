/**
 * Un-authenticates a user with an endpoint.  The endpoint must be interactive.
 * .
 * {code:bash}
 * endpoint logout
 * {code}
 **/
component {

	property name="EndpointService" inject="EndpointService";

	/**
	* @endpointName.hint Name of the endpoint to log out of
	* @username.hint Username for this user
	**/
	function run(
		required string endpointName,
		string username='' ) {

		try {

			endpointService.logoutEndpointUser( argumentCollection=arguments );

		} catch( endpointException var e ) {
			// This can include "expected" errors such as "Email already in use"
			error( e.message, e.detail );
		}

		if( len( arguments.username ) ) {
			print.greenLine( 'User [#arguments.username#] logged out successfully with [#arguments.endpointName#]' );
		} else {
			print.greenLine( 'All users logged out successfully with [#arguments.endpointName#]' );
		}
	}

}
