/**
 * Publishes a package with an endpoint.  The endpoint must be interactive.
 * .
 * {code:bash}
 * endpoint publish
 * {code}
 **/
component {

	property name="endpointService" 	inject="EndpointService";
	property name="packageService" 		inject="PackageService";
	property name='interceptorService'	inject='interceptorService';

	/**
	* @endpointName Name of the endpoint for which to publish the package
	* @directory    The directory being published
	* @force        Force the publish
	**/
	function run(
		required string endpointName,
		string directory='',
		boolean force = false
	){
		// This will make each directory canonical and absolute
		arguments.directory = resolvePath( arguments.directory );
		var boxJSON = packageService.readPackageDescriptor( arguments.directory );

		interceptorService.announceInterception( 'prePublish', { publishArgs=arguments, boxJSON=boxJSON } );

		try {

			endpointService.publishEndpointPackage( argumentCollection=arguments );

		} catch( endpointException var e ) {
			// This can include "expected" errors such as "Email already in use"
			error( e.message, e.detail );
		}

		interceptorService.announceInterception( 'postPublish', { publishArgs=arguments, boxJSON=boxJSON } );

		print.greenLine( 'Package published successfully in [#arguments.endpointName#]' );
	}

}
