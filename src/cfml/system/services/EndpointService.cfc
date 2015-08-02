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
	property name="logger"				inject="logbox:logger:{this}";
	property name="wirebox"				inject="wirebox";	
	property name="fileSystemUtil"		inject="FileSystem";
		property name="consoleLogger"	inject="logbox:logger:console";
	
	// Properties
	property name="endpointRegistry" type="struct";
	property name="endpointRootPath" type="string" default="/commandbox/system/endpoints";


	/**
	* Constructor
	*/
	function init(){
		setEndpointRegistry( {} );
		return this;
	}
	
	function onDIComplete() {
		buildEndpointRegistry();		
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
				var oEndPoint = wirebox.getInstance( endpointPath );
				var namePrefixs = listToArray( oEndPoint.getNamePrefixes() );
				for( var prefix in namePrefixs ) {
					endpointRegistry[ prefix ] = oEndPoint;
				}
			}
		}
		
	}
	
	/**
	* Inspects ID and returns name of endpoint.  If none is specified, tests for local file
	* or folder.  Defaults to forgebox.
	*/	
	struct function resolveEndpointData( required string ID, required string currentWorkingDirectory ) {
	
		var path = fileSystemUtil.resolvePath( arguments.ID, arguments.currentWorkingDirectory );
		// Is it a real zip file?
		if( listLast( path, '.' ) == 'zip' && fileExists( path ) ) {
			var endpointName = 'file';			
			return {
				endpointName : endpointName,
				package : path,
				ID : endpointName & ':' & path
			};
		// Is it a real folder?
		} else if( directoryExists( path ) ) {
			var endpointName = 'folder';			
			return {
				endpointName : endpointName,
				package : path,
				ID : endpointName & ':' & path
			};
		// Is it a GitHub user/repo?
		} else if( !findNoCase( ':', arguments.ID ) && listLen( arguments.ID, '/' ) == 2 ) {
			var endpointName =  'github';
			return {
				endpointName : endpointName,
				package : arguments.ID,
				ID : endpointName & ':' & arguments.ID
			};
		// Endpoint is specified as "endpoint:resource"
		} else if( listLen( arguments.ID, ':' ) > 1 ) {
			var endpointName = listFirst( arguments.ID, ':' );
			if( structKeyExists( getEndpointRegistry(), endpointName ) ) {
				return {
					endpointName : endpointName,
					package : listRest( arguments.ID, ':' ),
					ID : arguments.ID
				};
			} else {
				if( listFindNoCase( 'C,D,E,F,G,H', endpointName ) ) {
					consoleLogger.warn( "It appears you tried to type a file or folder path, but [#arguments.ID#] doesn't exist." );
				}
				throw( 'Endpoint [#endpointName#] not registered.', 'EndpointNotFound' );
			}
		// I give up, let's check ForgeBox (default endpoint)
		} else {
			var endpointName = 'forgebox';				
			return {
				endpointName : endpointName,
				package : arguments.ID,
				ID : endpointName & ':' & arguments.ID
			};
			
		} // End detecting endpoint
	}
	
	
	
	/**
	* Returns the endpoint object.
	*/	
	IEndpoint function getEndpoint( required string endpointName ) {
		var endpointRegistry = getEndpointRegistry();
		if( structKeyExists( endpointRegistry, arguments.endpointName ) ) {
			return endpointRegistry[ arguments.endpointName ];
		}
		
		// Didn't find it
		throw( 'Endpoint [#endpointName#] not registered.', 'EndpointNotFound' );
	}
	
	/**
	* Inspects ID and returns endpoint object, endpointName, and ID (with endpoint stripped).
	*/	
	struct function resolveEndpoint( required string ID, required string currentWorkingDirectory ) {
		var endpointData = resolveEndpointData(  arguments.ID, arguments.currentWorkingDirectory  );
		endpointData[ 'endpoint' ] = getEndpoint( endpointData.endpointName );
		return endpointData;
	}
	
}