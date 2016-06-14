/**
 * Publishes a package with an endpoint.  The endpoint must be interactive.
 * .
 * {code:bash}
 * endpoint publish
 * {code}
 **/
component {
	
	property name="EndpointService" inject="EndpointService";
	property name='interceptorService'	inject='interceptorService';	
	
	/**  
	* @endpointName.hint Name of the endpoint for which to publish the package
	* @username.hint Username for this user
	**/
	function run( 
		required string endpointName,
		string directory='' ) {			
		// This will make each directory canonical and absolute
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
		
		interceptorService.announceInterception( 'prePublish', { publishArgs=arguments } );
		
		try {
			
			endpointService.publishEndpointPackage( argumentCollection=arguments );
			
		} catch( endpointException var e ) {
			// This can include "expected" errors such as "Email already in use"
			error( e.message, e.detail );
		}
		
		interceptorService.announceInterception( 'postPublish', { publishArgs=arguments } );
		
		print.greenLine( 'Package published successfully in [#arguments.endpointName#]' );		
	}

}