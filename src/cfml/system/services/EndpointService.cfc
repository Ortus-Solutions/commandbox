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
	property name="tempDir" 			inject="tempDir@constants";
	property name="wirebox"				inject="wirebox";
	property name="fileSystemUtil"		inject="FileSystem";
	property name="consoleLogger"		inject="logbox:logger:console";
	property name="configService"		inject="configService";


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
	
	function onCLIStart() {
		buildEndpointRegistry();
		registerCustomForgeboxEndpoints();
	}

	/**
	* Inspect the endpoints folder and register them.
	*/
	function buildEndpointRegistry( string rootDirectory=getEndpointRootPath() ) {
		// Get the registry
		var endpointRegistry = getEndpointRegistry();
		// Inspect file system for endpoints
		var files = directoryList( expandPath( arguments.rootDirectory ) );

		for( var file in files ) {
			var endpointName = listFirst( listLast( file, '/\' ), '.' );
			// Ignore the interfaces
			if( !listFindNoCase( 'IEndPoint,IEndPointInteractive', endpointName ) ) {

				var endpointPath = listChangeDelims( arguments.rootDirectory, '/\', '.' ) & '.' & endpointName;
				var oEndPoint = wirebox.getInstance( endpointPath );
				if( endPointName == 'forgebox' ) {
					var customForgeBoxAPIURL = configService.getSetting( 'endpoints.forgebox.apiURL', '' );
					if( customForgeBoxAPIURL.len() ) {
						oEndPoint.getForgeBox().setEndpointURL( customForgeBoxAPIURL.reReplaceNoCase( '/api/.*', '' ) );
						oEndPoint.getForgeBox().setAPIURL( customForgeBoxAPIURL );
						oEndPoint.getForgeBox().setEndpointName( endpointName );
					}
				}
				registerEndpoint( oEndPoint );
			}
		}

	}


	/**
	* Look for custom ForgeBox endpoints that are in the config and register them
	* These will use the same base ForgeBox.cfc endpoint but with custom data
	*/
	function registerCustomForgeboxEndpoints() {
		var endpointConfigs = configService
			.getSetting( 'endpoints', {} )
			.filter( function( endpointName ) {
				return endpointName.lcase().startsWith( 'forgebox-' );
			} );

		for( var endpointName in endpointConfigs ) {
			var endpointData = endpointConfigs[ endpointName ];
			if( endpointData.keyExists( 'APIURL' ) && endpointData.APIURL.len() ) {

				var endpointPath = listChangeDelims( getEndpointRootPath(), '/\', '.' ) & '.ForgeBox';
				var oEndPoint = wirebox.getInstance( endpointPath );

				// Set the prefix for this endpoint
				oEndPoint.setNamePrefixes( endpointName.replaceNoCase( 'forgebox-', '' ) );

				// Set the API URL for this endpoint's forgebox Util
				oEndPoint.getForgeBox().setEndpointURL( endpointData.APIURL.reReplaceNoCase( '/api/.*', '' ) );
				oEndPoint.getForgeBox().setAPIURL( endpointData.APIURL );
				oEndPoint.getForgeBox().setEndpointName( endpointName.replaceNoCase( 'forgebox-', '' ) );

				// Register it, baby!
				registerEndpoint( oEndPoint );

			} else {
				consoleLogger.warn( 'ForgeBox endpoint [#endpointName#] doesn''t have a valid APIURL, skipping...' );
			}
		}

	}

	/**
	* Register a single CFC instance as an endpoint
	*
	* @oEndPoint An instance of a CFC implementing IEndPoint
	*/
	function registerEndpoint( required any oEndPoint ) {
		var namePrefixs = listToArray( oEndPoint.getNamePrefixes() );
		for( var prefix in namePrefixs ) {
			endpointRegistry[ prefix ] = oEndPoint;
		}
		return oEndPoint;
	}

	/**
	* Inspects ID and returns name of endpoint.  If none is specified, tests for local file
	* or folder.  Defaults to forgebox.
	* @ID The id of the endpoint
	* @currentWorkingDirectory Where we are working from
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
		// Does the ID contain at least one slash and is it a real folder path?
		} else if( listLen( arguments.ID, '\/' ) > 1 && directoryExists( path ) ) {
			var endpointName = 'folder';
			return {
				endpointName : endpointName,
				package : path,
				ID : endpointName & ':' & path
			};
		// Is it a GitHub user/repo?
		} else if( !findNoCase( ':', arguments.ID ) && !left( arguments.ID, 1 ) == "@" && listLen( arguments.ID, '/' ) == 2 ) {
			var endpointName =  'github';
			return {
				endpointName : endpointName,
				package : arguments.ID,
				ID : endpointName & ':' & arguments.ID
			};
		// Endpoint is specified as "endpoint:resource"
		} else if( listLen( arguments.ID, ':' ) > 1 ) {
			var endpointName = listFirst( arguments.ID, ':' );
			var package = listRest( arguments.ID, ':' );
			if( structKeyExists( getEndpointRegistry(), endpointName ) ) {
				var theID = arguments.ID;
				if( endpointName == 'file' || endpointName == 'folder' ) {
					package = fileSystemUtil.resolvePath( package, arguments.currentWorkingDirectory );
					if( endpointName == 'file' && !fileExists( package ) ) {
						throw( "The file [ #package# ] does not exist.", 'endpointException' );	
					}
					if( endpointName == 'folder' && !directoryExists( package ) ) {
						throw( "The folder [ #package# ] does not exist.", 'endpointException' );	
					}
					theID = endpointName & ':' & package;
				}
				return {
					endpointName : endpointName,
					package : package,
					ID : theID
				};
			} else {
				if( listFindNoCase( 'C,D,E,F,G,H', endpointName ) ) {
					consoleLogger.warn( "It appears you tried to type a file or folder path, but [#arguments.ID#] doesn't exist." );
				}
				throw( 'Endpoint [#endpointName#] not registered.', 'EndpointNotFound' );
			}
		// I give up, let's check ForgeBox (default endpoint)
		} else {
			var endpointName = configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );
			return {
				endpointName : endpointName,
				package : arguments.ID,
				ID : endpointName & ':' & arguments.ID
			};

		} // End detecting endpoint
	}

	/**
	* Returns the endpoint object.
	* @endpointName The name of the endpoint to retrieve
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
	* @ID The id of the endpoint
	* @currentWorkingDirectory Where we are working from
	*/
	struct function resolveEndpoint( required string ID, required string currentWorkingDirectory ) {
		var endpointData = resolveEndpointData(  argumentCollection = arguments  );
		endpointData[ 'endpoint' ] = getEndpoint( endpointData.endpointName );
		return endpointData;
	}

	/**
	* A facade to create a user with an interactive endpoint.  Keeping this logic here so I can standardize the storage
	* of the APIToken and make it reusable outside of the command.
	* @endpointName The name of the endpoint
	* @username ForgeBox username
	* @password The password
	* @email ForgeBox email
	* @firstName First name
	* @lastName Last Name
	*/
	function createEndpointUser(
		required string endpointName,
		required string username,
		required string password,
		required string email,
		required string firstName,
		required string lastName
	) {
		// Get all endpoints that are registered
		var endpointRegistry = getEndpointRegistry();
		// Confirm endpoint name exists
		if( !endpointRegistry.keyExists( arguments.endpointName ) ) {
			throw( "Sorry, the endpoint [#arguments.endpointName#] doesn't exist.  Valid names are [#endpointRegistry.keyList()#]", 'endpointException' );
		}

		// Get endpoint object
		var endpoint = getEndpoint( arguments.endpointName );

		// Confirm is interactive endpoint
		if( !isInstanceOf( endpoint, 'IEndpointInteractive' ) ) {
			throw( "Sorry, the endpoint [#arguments.endpointName#] does not support registering users.", 'endpointException' );		}

		// Create the user
		var APIToken = endpoint.createUser( argumentCollection=arguments );

		// Store the APIToken
		endpoint.storeAPIToken( arguments.username, APIToken );
	}

	/**
	* A facade to login a user with an interactive endpoint.  Keeping this logic here so I can standardize the storage
	* of the APIToken and make it reusable outside of the command.
	* @endpointName The name of the endpoint
	* @username The username
	* @password The password to use
	*/
	function loginEndpointUser(
		required string endpointName,
		required string username,
		required string password
	) {
		// Get all endpoints that are registered
		var endpointRegistry = getEndpointRegistry();
		// Confirm endpoint name exists
		if( !endpointRegistry.keyExists( arguments.endpointName ) ) {
			throw( "Sorry, the endpoint [#arguments.endpointName#] doesn't exist.  Valid names are [#endpointRegistry.keyList()#]", 'endpointException' );
		}

		// Get endpoint object
		var endpoint = getEndpoint( arguments.endpointName );

		// Confirm is interactive endpoint
		if( !isInstanceOf( endpoint, 'IEndpointInteractive' ) ) {
			throw( "Sorry, the endpoint [#arguments.endpointName#] does not support logging in users.", 'endpointException' );		}

		// Login the user
		var APIToken = endpoint.login( argumentCollection=arguments );

		// Store the APIToken
		endpoint.storeAPIToken( arguments.username, APIToken );

	}

	/**
	* A facade to logout a user with an interactive endpoint.  Keeping this logic here so I can standardize the storage
	* of the APIToken and make it reusable outside of the command.  Passing no username should log out all users.
	* @endpointName The name of the endpoint
	* @username The username
	*/
	function logoutEndpointUser(
		required string endpointName,
		required string username=''
	) {
		// Get all endpoints that are registered
		var endpointRegistry = getEndpointRegistry();
		// Confirm endpoint name exists
		if( !endpointRegistry.keyExists( arguments.endpointName ) ) {
			throw( "Sorry, the endpoint [#arguments.endpointName#] doesn't exist.  Valid names are [#endpointRegistry.keyList()#]", 'endpointException' );
		}

		// Get endpoint object
		var endpoint = getEndpoint( arguments.endpointName );

		// Confirm is interactive endpoint
		if( !isInstanceOf( endpoint, 'IEndpointInteractive' ) ) {
			throw( "Sorry, the endpoint [#arguments.endpointName#] does not support logging out users.", 'endpointException' );		}

		// Logout the user
		endpoint.logout( argumentCollection=arguments );
	}

	/**
	* A facade to publish a package with an interactive endpoint.
	* @endpointName The name of the endpoint to publish to
	* @directory The directory to publish
	*/
	function publishEndpointPackage(
		required string endpointName,
		required string directory,
		boolean upload = false,
		boolean forceUpload = false
	) {
		// Get all endpoints that are registered
		var endpointRegistry = getEndpointRegistry();
		// Confirm endpoint name exists
		if( !endpointRegistry.keyExists( arguments.endpointName ) ) {
			throw( "Sorry, the endpoint [#arguments.endpointName#] doesn't exist.  Valid names are [#endpointRegistry.keyList()#]", 'endpointException' );
		}

		// Get endpoint object
		var endpoint = getEndpoint( arguments.endpointName );

		// Confirm is interactive endpoint
		if( !isInstanceOf( endpoint, 'IEndpointInteractive' ) ) {
			throw( "Sorry, the endpoint [#arguments.endpointName#] does not support publishing packages.", 'endpointException' );
		}
		// Set the path to publish
		arguments.path = arguments.directory;

		// Publish the package
		endpoint.publish( argumentCollection=arguments );
	}


	/**
	* A facade to unpublish a package with an interactive endpoint.
	* @endpointName The name of the endpoint to publish to
	* @directory The directory to publish
	* @version The version to unpublish
	*/
	function unpublishEndpointPackage(
		required string endpointName,
		required string directory,
		string version=''
	) {
		// Get all endpoints that are registered
		var endpointRegistry = getEndpointRegistry();
		// Confirm endpoint name exists
		if( !endpointRegistry.keyExists( arguments.endpointName ) ) {
			throw( "Sorry, the endpoint [#arguments.endpointName#] doesn't exist.  Valid names are [#endpointRegistry.keyList()#]", 'endpointException' );
		}

		// Get endpoint object
		var endpoint = getEndpoint( arguments.endpointName );

		// Confirm is interactive endpoint
		if( !isInstanceOf( endpoint, 'IEndpointInteractive' ) ) {
			throw( "Sorry, the endpoint [#arguments.endpointName#] does not support unpublishing packages users.", 'endpointException' );
		}
		// Set the path to publish
		arguments.path = arguments.directory;
		// Publish the package
		endpoint.unpublish( argumentCollection=arguments );
	}



	function forgeboxEndpointNameComplete() {
		return configService
			.getSetting( 'endpoints', {} )
			.filter( function( endpointName ) {
				return (endpointName.lcase().startsWith( 'forgebox-' ) || endpointName == 'forgebox' );
			} )
			.reduce( function( endpoints, endpointName ) {
				endpoints.append( endpointName.replaceNoCase( 'forgebox-', '' ) );
				return endpoints;
			}, [] );
	}

}
