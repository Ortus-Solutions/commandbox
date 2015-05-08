/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle working with Endpoints
*/
component accessors="true" singleton {

	// DI
	property name="logger"			inject="logbox:logger:{this}";
	property name="wirebox"			inject="wirebox";	
	property name="fileSystemUtil"	inject="FileSystem";
	
	// Properties
	property name="endpointRegistry" type="struct" default="#{}#";
	property name="endpointRootPath" type="string" default="/commandbox/system/endpoints";


	/**
	* Constructor
	*/
	function init(){
		buildEndpointRegistry();
		return this;
	}
	
	/**
	* Inspect the endpoints folder and register them.
	*/	
	function buildEndpointRegistry() {
		// Get the registry
		var endpointRegistry = getEndpointRegistry();
		// Inspect file system for endpoints
		var files = directoryList( getEndpointRootPath() );
		
		for( var file in files ) {
			var endpointName = listFirst( listLast( file, '/\' ), '.' );
			// Ignore the interfaces
			if( !listFindNoCase( 'IEndPoint,IEndPointInteractive', endpointName ) ) {
				
				var endpointPath = listChangeDelims( getEndpointRootPath(), '/\', '.' ) & '.' & endpointName;
				var oEndPoint = wirebox.getInstnce( endpointPath );
				var namePrefixs = listToArray( oEndPoint.getNamePrefixs() );
				for( var prefix in namePrefixs ) {
					endpointRegistry[ endpointName ] = oEndPoint;
				}
			}
		}
		
	}
	
	/**
	* Inspects ID and returns name of endpoint.  If none is specified, tests for local file
	* or folder.  Defaults to forgebox.
	*/	
	string function determinEndpoint( required string ID, required string currentWorkingDirectory ) {
		// Endpoint is specified as "endpoint:resource"
		if( listLen( arguments.ID, ':' ) ) {
			var endpointName = listFirst( arguments.ID, ':' );
			if( structKeyExists( getEndpointRegistry(), endpointName ) ) {
				return endpointName;
			} else {
				throw( 'Endpoint [#endpointName#] not registered.');
			}
		// Endpoint not specified, let's look for it
		} else {
			var path = fileSystemUtil.resolvePath( arguments.ID, arguments.currentWorkingDirectory );
			// Is it a file?
			if( fileExists( path ) ) {
				return 'file';
			// Is it a folder
			} else if( directoryExists( path ) ) {
				return 'folder';
			// I give up, let's check ForgeBox (default endpoint)
			} else {
				return 'forgebox';				
			}
			
		} // End detecting endpoint
	}
	
	
}