/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the ForgeBox endpoint.  I wrap CFML's coolest package repository EVER!
*/
component accessors="true" implements="IEndpointInteractive" singleton {

	// DI
	property name="CR" 					inject="CR@constants";
	property name="consoleLogger"		inject="logbox:logger:console";
	property name="forgeBox" 			inject="ForgeBox";
	property name="tempDir" 			inject="tempDir@constants";
	property name="semanticVersion"		inject="provider:semanticVersion@semver";
	property name="artifactService" 	inject="ArtifactService";
	property name="packageService" 		inject="packageService";
	property name="configService" 		inject="configService";
	property name="endpointService"		inject="endpointService";
	property name="fileSystemUtil"		inject="FileSystem";
	property name="fileEndpoint"		inject="commandbox.system.endpoints.File";

	// Properties
	property name="namePrefixes" type="string";

	/**
	 * Constructor
	 */
	function init() {
		setNamePrefixes( 'forgebox' );
		return this;
	}

	/**
	 * Resolve a package
	 * @package The package to resolve
	 * @verbose Verbose flag or silent, defaults to false
	 */
	public string function resolvePackage( required string package, boolean verbose=false ) {
		var slug 	= parseSlug( arguments.package );
		var version = parseVersion( arguments.package );
		var strVersion = semanticVersion.parseVersion( version );

		// If we have a specific version and it exists in artifacts and this isn't a snapshot build, use it.  Otherwise, to ForgeBox!!
		if( semanticVersion.isExactVersion( version ) && artifactService.artifactExists( slug, version ) && strVersion.preReleaseID != 'snapshot' ) {
			consoleLogger.info( "Package found in local artifacts!");
			// Install the package
			var thisArtifactPath = artifactService.getArtifactPath( slug, version );
			// Defer to file endpoint
			return fileEndpoint.resolvePackage( thisArtifactPath, arguments.verbose );
		} else {
			return getPackage( slug, version, arguments.verbose );
		}
	}

	/**
	 * Get default name for a package
	 * @package The package to resolve
	 */
	public function getDefaultName( required string package ) {
		// if "foobar@2.0" just return "foobar"
		return listFirst( arguments.package, '@' );
	}

	/**
	 * Get an update for a package
	 * @package The package name
	 * @version The package version
	 * @verbose Verbose flag or silent, defaults to false
	 *
	 * @return struct { isOutdated, version }
	 */
	public function getUpdate( required string package, required string version, boolean verbose=false ) {
		var APIToken		= configService.getSetting( 'endpoints.forgebox.APIToken', '' );
		var slug 			= parseSlug( arguments.package );
		var boxJSONversion 	= parseVersion( arguments.package );
		var result 			= {
								isOutdated 	= false,
								version 	= ''
							  };

		// Only bother checking if we have a version range.  If an exact version is stored in
		// box.json, we're never going to update it anyway.
		if( semanticVersion.isExactVersion( boxJSONversion ) ) {
			return result;
		}

		try {

			// Verify in ForgeBox
			var entryData = forgebox.getEntry( slug, APIToken );

		} catch( forgebox var e ) {
			// This can include "expected" errors such as "Email already in use"
			throw( e.message, 'endpointException', e.detail );
		}

		entryData.versions.sort( function( a, b ) { return semanticVersion.compare( b.version, a.version ) } );

		var found = false;
		for( var thisVersion in entryData.versions ) {
			// Look for a version on ForgeBox that satisfies our range
			if( semanticVersion.satisfies( thisVersion.version, boxJSONversion ) ) {
				result.version = thisVersion.version;
				found = true;
				// Only flag it as outdated if the matching version is newer.
				if( semanticVersion.isNew( current=version, target=thisVersion.version, checkBuildID=false ) ) {
					result.isOutdated = true;
				}
				break;
			}
		}

		if( !found ) {
			// If we requsted stable and all releases are pre-release, just grab the latest
			if( boxJSONversion == 'stable' && arrayLen( entryData.versions ) ) {
				result.version = entryData.versions[ 1 ].version;
				result.isOutdated = true;
			}
		}

		return result;
	}

	/**
	 * Create a new user in ForgeBox
	 * @username ForgeBox username
	 * @password The password
	 * @email ForgeBox email
	 * @firstName First name
	 * @lastName Last Name
	 *
	 * @return The API Token of the registered user.
	 */
	public string function createUser(
		required string username,
		required string password,
		required string email,
		required string firstName,
		required string lastName
	){
		var APIToken = configService.getSetting( 'endpoints.forgebox.APIToken', '' );

		try {

			var results = forgebox.register(
				username = arguments.username,
				password = arguments.password,
				email 	= arguments.email,
				FName 	= arguments.firstName,
				LName 	= arguments.lastName,
				APIToken = APIToken
			);
			return results.APIToken;

		} catch( forgebox var e ) {
			// This can include "expected" errors such as "Email already in use"
			throw( e.message, 'endpointException', e.detail );
		}
	}

	/**
	 * Login a user into ForgeBox
	 * @username The username
	 * @password The password to use
	 *
	 * @return The API Token of the registered user.
	 */
	public string function login( required string userName, required string password ) {
		try {

			var results = forgebox.login( argumentCollection=arguments );
			return results.APIToken;

		} catch( forgebox var e ) {
			// This can include "expected" errors such as "Email already in use"
			throw( e.message, 'endpointException', e.detail );
		}
	}

	/**
	 * Publish a package in ForgeBox
	 * @path The path to publish
	 */
	public function publish(
		required string path,
		string zipPath = "",
		boolean force = false
	) {
		// start upload stuff here
		var upload = boxJSON.location == "forgeboxStorage";

		if( var upload ){
			arguments.zipPath = createZipFromPath( arguments.path );
		}

		if( !packageService.isPackage( arguments.path ) ) {
			throw(
				'Sorry but [#arguments.path#] isn''t a package.',
				'endpointException',
				'Please double check you''re in the correct directory or use "package init" to turn your directory into a package.'
			);
		}

		var boxJSON = packageService.readPackageDescriptor( arguments.path );

		var props = {}
		props.slug = boxJSON.slug;
		props.private = boxJSON.private;
		props.version = boxJSON.version;
		props.boxJSON = serializeJSON( boxJSON );
		props.isStable = !semanticVersion.isPreRelease( boxJSON.version );
		props.description = boxJSON.description;
		props.descriptionFormat = 'text';
		props.installInstructions = boxJSON.instructions;
		props.installInstructionsFormat = 'text';
		props.changeLog = boxJSON.changeLog;
		props.changeLogFormat = 'text';
		props.APIToken = configService.getSetting( 'endpoints.forgebox.APIToken', '' );
		props.zipPath = arguments.zipPath;
		props.forceUpload = arguments.force;

		// Look for readme, instruction, and changelog files
		for( var item in [
			{ variable : 'description', file : 'readme' },
			{ variable : 'installInstructions', file : 'instructions' },
			{ variable : 'changelog', file : 'changelog' }
		] ) {
			// Check for no ext or .txt or .md in reverse precendence.
			for( var ext in [ '', '.txt', '.md' ] ) {
				// Case insensitive search for file name
				var files = directoryList( path=arguments.path, filter=function( path ){ return path contains ( item.file & ext); } );0
				if( arrayLen( files ) ) {
					// If found, read in the first one found.
					props[ item.variable ] = fileRead( files[ 1 ] );
					props[ item.variable & 'Format' ] = ( ext == '.md' ? 'md' : 'text' );
				}
			}
		}

		try {
			consoleLogger.warn( "Sending package information to ForgeBox, please wait..." );
			if( len( props.zipPath ) ){
				consoleLogger.warn( "Uploading package zip to ForgeBox..." );
			}

			forgebox.publish( argumentCollection=props );

			if( ! isNull( arguments.zipPath ) ){
				if( fileExists( arguments.zipPath ) ){
					fileDelete( arguments.zipPath );
				}
			}

			consoleLogger.info( "Package is alive, you can visit it here: #forgebox.getEndpointURL()#/view/#boxJSON.slug#" );
		} catch( forgebox var e ) {
			// This can include "expected" errors such as "User not authenticated"
			throw( e.message, 'endpointException', e.detail );
		}
	}

	/**
	 * Unpublish a package in ForgeBox
	 * @path The path to publish
	 * @version The version to publish
	 */
	public function unpublish( required string path, string version='') {

		if( !packageService.isPackage( arguments.path ) ) {
			throw(
				'Sorry but [#arguments.path#] isn''t a package.',
				'endpointException',
				'Please double check you''re in the correct directory.'
			);
		}

		var boxJSON = packageService.readPackageDescriptor( arguments.path );

		try {
			consoleLogger.warn( "Unpublishing package [#boxJSON.slug##( len( arguments.version ) ? '@' : '' )##arguments.version#] from ForgeBox, please wait..." );

			forgebox.unpublish( boxJSON.slug, arguments.version, configService.getSetting( 'endpoints.forgebox.APIToken', '' ) );

		} catch( forgebox var e ) {
			// This can include "expected" errors such as "User not authenticated"
			throw( e.message, 'endpointException', e.detail );
		}
	}

	/**
	* Figures out what version of a package would be installed with a given semver range without actually going through the installation.
	* @slug Slug of package
	* @version Version range to satisfy
	* @entryData Optional struct of entryData which skips the ForgeBox call.
	*/
	function findSatisfyingVersion( required string slug, required string version, struct entryData ) {
		var APIToken = configService.getSetting( 'endpoints.forgebox.APIToken', '' );
		 try {
			// Use passed in entrydata, or go get it from ForgeBox.
			arguments.entryData = arguments.entryData ?: forgebox.getEntry( arguments.slug, APIToken );
		} catch( forgebox var e ) {
			// This can include "expected" errors such as "User not authenticated"
			throw( e.message, 'endpointException', e.detail );
		}

		arguments.entryData.versions.sort( function( a, b ) { return semanticVersion.compare( b.version, a.version ) } );

		var found = false;
		for( var thisVersion in arguments.entryData.versions ) {
			if( semanticVersion.satisfies( thisVersion.version, arguments.version ) ) {
				return thisVersion;
			}
		}

		// If we requsted stable and all releases are pre-release, just grab the latest
		if( arguments.version == 'stable' && arrayLen( arguments.entryData.versions ) ) {
			return arguments.entryData.versions[ 1 ];
		} else {
			throw( 'Version [#arguments.version#] not found for package [#arguments.slug#].', 'endpointException', 'Available versions are [#arguments.entryData.versions.map( function( i ){ return ' ' & i.version; } ).toList()#]' );
		}
	}

	/**
	* Parses just the slug portion out of an endpoint ID
	* @package The full endpointID like foo@1.0.0
	*/
	public function parseSlug( required string package ) {
		var matches = REFindNoCase( "^((?:@[\w\-]+\/)?[\w\-]+)(?:@(.+))?", package, 1, true );
		if ( arrayLen( matches.len ) < 2 ) {
			throw(
				type = "endpointException",
				message = "Invalid slug detected.  Slugs can only contain letters, numbers, underscores, and hyphens. They may also be prepended with an @ sign for private packages"
			);
		}
		return mid( package, matches.pos[ 2 ], matches.len[ 2 ] );
	}

	/**
	* Parses just the version portion out of an endpoint ID
	* @package The full endpointID like foo@1.0.0
	*/
	public function parseVersion( required string package ) {
		var version = 'stable';
		// foo@1.0.0
		var matches = REFindNoCase( "^((?:@[\w\-]+\/)?[\w\-]+)(?:@(.+))?", package, 1, true );
		if ( matches.pos.len() >= 3 && matches.pos[ 3 ] != 0 ) {
			// Note this can also be a semver range like 1.2.x, >2.0.0, or 1.0.4-2.x
			// For now I'm assuming it's a specific version
			version = mid( package, matches.pos[ 3 ], matches.len[ 3 ] );
		}
		return version;
	}


	/****************************************** PRIVATE ******************************************/

	/**
	 * Get a package path location
	 * @slug The package slug
	 * @version The package version
	 * @verbose Verbose flag or silent, defaults to false
	 */
	private function getPackage( slug, version, verbose=false ) {

		var APIToken = configService.getSetting( 'endpoints.forgebox.APIToken', '' );

		try {
			// Info
			consoleLogger.warn( "Verifying package '#slug#' in ForgeBox, please wait..." );

			var entryData = forgebox.getEntry( slug, APIToken );

			// Verbose info
			if( arguments.verbose ){
				consoleLogger.debug( "Package data retrieved: ", entryData );
			}

			// entrylink,createdate,lname,isactive,installinstructions,typename,version,hits,coldboxversion,sourceurl,slug,homeurl,typeslug,
			// downloads,entryid,fname,changelog,updatedate,downloadurl,title,entryrating,summary,username,description,email

			if( !entryData.isActive ) {
				throw( 'The ForgeBox entry [#entryData.title#] is inactive.', 'endpointException' );
			}

			var satisfyingVersion = findSatisfyingVersion( slug, version, entryData );
			arguments.version = satisfyingVersion.version;
			var downloadURL = satisfyingVersion.downloadURL;

			if( !len( downloadurl ) ) {
				throw( 'No download URL provided in ForgeBox.  Manual install only.', 'endpointException' );
			}

			consoleLogger.info( "Installing version [#arguments.version#]." );

			try {
				forgeBox.recordInstall( arguments.slug, arguments.version, APIToken );
			} catch( forgebox var e ) {
				consoleLogger.warn( e.message & CR & e.detail );
			}

			var packageType = entryData.typeSlug;

			// Advice we found it
			consoleLogger.info( "Verified entry in ForgeBox: '#slug#'" );

			var strVersion = semanticVersion.parseVersion( version );

			// If the local artifact doesn't exist or it's a snapshot build, download and create it
			if( !artifactService.artifactExists( slug, version ) || strVersion.preReleaseID == 'snapshot' ) {

				// Test package location to see what endpoint we can refer to.
				var endpointData = endpointService.resolveEndpoint( downloadURL, 'fakePath', arguments.slug, arguments.version );

				consoleLogger.info( "Deferring to [#endpointData.endpointName#] endpoint for ForgeBox entry [#slug#]..." );

				var packagePath = endpointData.endpoint.resolvePackage( endpointData.package, arguments.verbose );

				// Cheat for people who set a version, slug, or type in ForgeBox, but didn't put it in their box.json
				var boxJSON = packageService.readPackageDescriptorRaw( packagePath );
				if( !structKeyExists( boxJSON, 'type' ) || !len( boxJSON.type ) ) { boxJSON.type = entryData.typeslug; }
				if( !structKeyExists( boxJSON, 'slug' ) || !len( boxJSON.slug ) ) { boxJSON.slug = entryData.slug; }
				if( !structKeyExists( boxJSON, 'version' ) || !len( boxJSON.version ) ) { boxJSON.version = version; }
				packageService.writePackageDescriptor( boxJSON, packagePath );

				consoleLogger.info( "Storing download in artifact cache..." );

				// Store it locally in the artfact cache
				artifactService.createArtifact( slug, version, packagePath );

				consoleLogger.info( "Done." );

				return packagePath;

			} else {
				consoleLogger.info( "Package found in local artifacts!");
				var thisArtifactPath = artifactService.getArtifactPath( slug, version );
				// Defer to file endpoint
				return fileEndpoint.resolvePackage( thisArtifactPath, arguments.verbose );
			}


		} catch( forgebox var e ) {

			consoleLogger.error( ".");
			consoleLogger.error( "Aww man,  ForgeBox isn't feeling well.");
			consoleLogger.debug( "#e.message#  #e.detail#");
			consoleLogger.error( "We're going to look in your local artifacts cache and see if one of those versions will work.");

			// See if there's something usable in the artifacts cache.  If so, we'll use that version.
			var satisfyingVersion = artifactService.findSatisfyingVersion( slug, version );

			if( len( satisfyingVersion ) ) {
				consoleLogger.info( ".");
				consoleLogger.info( "Sweet! We found a local version of [#satisfyingVersion#] that we can use in your artifacts.");
				consoleLogger.info( ".");

				var thisArtifactPath = artifactService.getArtifactPath( slug, satisfyingVersion );
				// Defer to file endpoint
				return fileEndpoint.resolvePackage( thisArtifactPath, arguments.verbose );
			} else {
				throw( 'No satisfying version found for [#version#].', 'endpointException', 'Well, we tried as hard as we can.  ForgeBox is unreachable and you don''t have a usable version in your local artifacts cache.  Please try another version.' );
			}

		}
	}

	private function createZipFromPath( required string path ) {
		if( !packageService.isPackage( arguments.path ) ) {
			throw(
				'Sorry but [#arguments.path#] isn''t a package.',
				'endpointException',
				'Please double check you''re in the correct directory or use "package init" to turn your directory into a package.'
			);
		}
		var boxJSON = packageService.readPackageDescriptor( arguments.path );
		var ignorePatterns = ( isArray( boxJSON.ignore ) ? boxJSON.ignore : [] );
		var tmpPath = tempDir & hash( arguments.path );
		if ( directoryExists( tmpPath ) ) {
			directoryDelete( tmpPath, true );
		}
		directoryCreate( tmpPath );
		directoryCopy( arguments.path, tmpPath, true, function( directoryPath ){
			// This will normalize the slashes to match
			directoryPath = fileSystemUtil.resolvePath( directoryPath );
			// Directories need to end in a trailing slash
			if( directoryExists( directoryPath ) ) {
				directoryPath &= server.separator.file;
			}
			// cleanup path so we just get from the archive down
			var thisPath = replacenocase( directoryPath, tmpPath, "" );
			// Ignore paths that match one of our ignore patterns
			var ignored = pathPatternMatcher.matchPatterns( ignorePatterns, thisPath );
			// What do we do with this file/directory
			return ! ignored;
		});
		var zipFileName = tmpPath & ".zip";
		cfzip(
			action = "zip",
			file = zipFileName,
			overwrite = true,
			source = tmpPath
		);
		directoryDelete( tmpPath, true );
		return zipFileName;
	}

}
