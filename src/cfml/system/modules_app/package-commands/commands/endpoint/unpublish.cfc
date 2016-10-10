/**
 * Unpublishes a package or a package version with an endpoint.  The endpoint must be interactive.
 * .
 * {code:bash}
 * endpoint unpublish
 * endpoint unpublish 1.2.3
 * {code}
 **/
component {
	
	property name="endpointService" 	inject="EndpointService";
	property name="packageService" 		inject="PackageService";
	property name='interceptorService'	inject='interceptorService';	
	
	/**  
	* @endpointName Name of the endpoint for which to unpublish the package
	* @version The version being unpublished
	* @directory The directory being unpublished
	* @force Skip the prompt
	**/
	function run( 
		required string endpointName,
		string version='',
		string directory='',
		boolean force=false
	){			
		// This will make each directory canonical and absolute
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
		var boxJSON = packageService.readPackageDescriptor( arguments.directory );

		if( !arguments.force && !confirm( 'Are you sure you want to unpublish? This is descrtuctive and can''t be undone.' ) ) {
			error( 'Cancelled!' );
		}

		interceptorService.announceInterception( 'preUnpublish', { unpublishArgs=arguments, boxJSON=boxJSON } );
		
		try {
			
			endpointService.unpublishEndpointPackage( argumentCollection=arguments );
			
		} catch( endpointException var e ) {
			// This can include "expected" errors such as "Email already in use"
			error( e.message, e.detail );
		}
		
		interceptorService.announceInterception( 'postUnpublish', { unpublishArgs=arguments, boxJSON=boxJSON } );
		
		if( len( arguments.version ) ) {
			print.greenLine( 'Package version [#boxJSON.slug#@#arguments.version#] unpublished successfully in [#arguments.endpointName#]' );	
		} else {
			print.greenLine( 'Package [#boxJSON.slug#] unpublished successfully in [#arguments.endpointName#]' );			
		}
	}

}