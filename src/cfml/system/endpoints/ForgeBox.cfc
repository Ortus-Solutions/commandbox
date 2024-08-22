/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the ForgeBox endpoint.  I wrap CFML's coolest package repository EVER!
*/
component accessors="true" implements="IEndpointInteractive" {

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
	property name="lexEndpoint"			inject="commandbox.system.endpoints.Lex";
	property name='wirebox'				inject='wirebox';
	property name='logger'				inject='logbox:logger:{this}';

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
	public string function resolvePackage( required string package, string currentWorkingDirectory="", boolean verbose=false ) {
		var boxJSON = {}
		if( len( currentWorkingDirectory ) && directoryExists( currentWorkingDirectory ) ) {
			boxJSON = packageService.readPackageDescriptor( currentWorkingDirectory );
		}

		var job = wirebox.getInstance( 'interactiveJob' );
		var slug 	= parseSlug( arguments.package );
		var defaultVersion = boxJSON.dependencies[slug] ?: boxJSON.devDependencies[slug] ?: 'stable';
		var version = parseVersion( arguments.package, defaultVersion );
		var strVersion = semanticVersion.parseVersion( version, defaultVersion );

		// If we have a specific version and it exists in artifacts and this isn't a snapshot build, use it.  Otherwise, to ForgeBox!!
		if( semanticVersion.isExactVersion( version ) && artifactService.artifactExists( slug, version ) && strVersion.preReleaseID != 'snapshot' ) {
			job.addLog( "Package found in local artifacts!");
			// Install the package
			var thisArtifactPath = artifactService.getArtifactPath( slug, version );

			recordInstall( slug, version );

			// Defer to file endpoint
			return fileEndpoint.resolvePackage( thisArtifactPath, currentWorkingDirectory, arguments.verbose );
		} else {
			return getPackage( slug, version, currentWorkingDirectory, arguments.verbose );
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
		var APIToken		= getAPIToken();
		var slug 			= parseSlug( arguments.package );
		var boxJSONversion 	= parseVersion( arguments.package );
		var result 			= {
            isOutdated 	= false,
            version 	= boxJSONversion
        };

		// Only bother checking if we have a version range.  If an exact version is stored in
		// box.json, we're never going to update it anyway.
		// UNLESS the box.json has been updated to have a new exact version that is different from what's installed (ignoring buildID)
		if( semanticVersion.isExactVersion( boxJSONversion ) && semanticVersion.compare( boxJSONversion, version, false ) == 0 ) {
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
			// If we requested stable and all releases are pre-release, just grab the latest
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
		var APIToken = getAPIToken();

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
	 * Log a user out of ForgeBox
	 * @username The username
	 */
	public function logout( string userName='' ) {
		var settingBase = 'endpoints.forgebox' & ( getNamePrefixes() == 'forgebox' ? '' : '-' & getNamePrefixes() );

		// Remove ALL login data for this endpoint
		if( !len( userName ) ) {
			configService.removeSetting( settingBase );
			return;
		}

		// If the user being logged out is the current one in use, remove the current API Token as well, otherwise leave whatever other user is set in place
		if( configService.getSetting( settingBase & '.tokens.#userName#', '' ) == configService.getSetting( settingBase & '.APIToken', '' ) ) {
			configService.removeSetting( settingBase & '.APIToken' );
		}

		// Finally, remove stored token for this user
		configService.removeSetting( settingBase & '.tokens.#userName#' );

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
		props.APIToken = getAPIToken();
		props.forceUpload = arguments.force;
		props.binaryHash = '';

		// start upload stuff here
		var upload = boxJSON.location == "forgeboxStorage";

		if( upload ){
			try {
				forgebox.getStorageLocation( props.slug, props.version, props.APIToken );
				if ( ! arguments.force ) {
					consoleLogger.error( "A zip for this version has already been uploaded.  If you want to override the uploaded zip, run this command with the `force` flag.  We will continue to update your package metadata." );
					upload = false;
				}
			}
			catch ( any e ) {
				if ( e.errorCode != 404 ) {
					rethrow;
				}
			}
		}

		// Look for readme, instruction, and changelog files
		for( var item in [
			{ variable : 'description', file : 'readme' },
			{ variable : 'installInstructions', file : 'instructions' },
			{ variable : 'changelog', file : 'changelog' }
		] ) {
			// Check for no ext or .txt or .md in reverse precedence.
			for( var ext in [ '', '.txt', '.md' ] ) {
				// Case insensitive search for file name
				var files = directoryList( path=arguments.path, filter=function( path ){ return path contains ( item.file & ext); } );
				if( arrayLen( files ) && fileExists( files[ 1 ] ) ) {
					// If found, read in the first one found.
					props[ item.variable ] = fileRead( files[ 1 ], 'UTF-8' );
					props[ item.variable & 'Format' ] = ( ext == '.md' ? 'md' : 'text' );
				}
			}
		}

		// validation goes here
		var validationData = {
			"slug": {
				"maxLen": 255,
				"required": true
			},
			"version": {
				"maxLen": 25
			},
			"shortDescription": {
				"maxLen": 200
			},
			"name": {
				"maxLen": 255
			},
			"homepage": {
				"maxLen": 500
			},
			"documentation": {
				"maxLen": 255
			},
			"bugs": {
				"maxLen": 255
			},
			"repository.URL": {
				"maxLen": 500
			}
		};

		var errors = [];
		consoleLogger.info( "Start validation..." );
		validationData.each( ( prop, validData ) => {
			if( validData.keyExists( 'required' ) ) {
				if( len( Evaluate( "boxJSON.#prop#" ) ) == 0 ) {
					errors.append( "[#prop#] is required" );
				}
			}
			if( validData.keyExists( 'maxLen' ) ) {
				if( isDefined( "boxJSON.#prop#" ) && len( Evaluate( "boxJSON.#prop#" ) ) > validData[ "maxLen" ] ) {
					errors.append( "[#prop#] must be #validData[ 'maxLen' ]# characters or shorter" );
				}
			}

		} );

		// validation message if errors show up
		if( errors.len() > 0 ){
			errors.append( "#chr(10)#Please fix the invalid data and try publishing again." );
			throw( "There were validation errors in publishing...", "endpointException", errors.toList( chr(10) ) );
		}

		try {
			if ( upload ) {
				consoleLogger.warn( "Creating zip artifact from local files..." );
				var zipPath = createZipFromPath( arguments.path );
				var zipSizeB = getfileInfo( zipPath ).size;
				var zipSizeKB = int( zipSizeB/1024 );
				if( zipSizeB < 1024 ) {
					var readableSize = zipSizeB & " Bytes";
				} else if( zipSizeKB > 1024 ) {
					var readableSize = numberFormat( zipSizeKB/1024, "0.0" ) & " MB";
				} else {
					var readableSize = zipSizeKB & " KB";
				}
				consoleLogger.warn( "Uploading package zip [#readableSize#] to #getNamePrefixes()#..." );
				var storeURL = forgebox.storeURL( props.slug, props.version, props.APIToken );
				var binary = fileReadBinary( zipPath );

				http
					url="#storeURL#"
					throwOnError=false
					method="PUT"
					proxyServer="#ConfigService.getSetting( 'proxy.server', '' )#"
					proxyPort="#ConfigService.getSetting( 'proxy.port', 80 )#"
					proxyUser="#ConfigService.getSetting( 'proxy.user', '' )#"
					proxyPassword="#ConfigService.getSetting( 'proxy.password', '' )#"
					result="local.storeResult"{
						httpparam type="header" name="Content-Type" value="application/zip";
						httpparam type="body" value="#binary#";
					}

				props.binaryHash = hash( binary, "MD5" );

				if( fileExists( zipPath ) ){
					fileDelete( zipPath );
				}

				if( local.storeResult.status_code != 200 ) {
					consoleLogger.error( "Error uploading zip file to #getNamePrefixes()# [#local.storeResult.statusCode#]..." );
					throw( local.storeResult.fileContent, "endpointException" )
				}
				consoleLogger.info( "Success!" );
			}

			consoleLogger.warn( "Sending package information to #getNamePrefixes()#..." );
			forgebox.publish( argumentCollection=props );


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
			consoleLogger.warn( "Unpublishing package [#boxJSON.slug##( len( arguments.version ) ? '@' : '' )##arguments.version#] from #getNamePrefixes()#, please wait..." );

			forgebox.unpublish( boxJSON.slug, arguments.version, getAPIToken() );

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
		var APIToken = getAPIToken();
		 try {
			// Use passed in entrydata, or go get it from ForgeBox.
			arguments.entryData = arguments.entryData ?: forgebox.getEntry( arguments.slug, APIToken );
		} catch( forgebox var e ) {
			// This can include "expected" errors such as "User not authenticated"
			throw( e.message, 'endpointException', e.detail );
		}

		// If this is an exact version (not a range) just do a simple lookup for it
		if( semanticVersion.isExactVersion( version, true ) ) {
			for( var thisVer in arguments.entryData.versions ) {
				if( semanticVersion.isEQ( version, thisVer.version, true ) ) {
					return thisVer;
				}
			}
			var availVersions = arguments.entryData.versions;
			if( availVersions.len() > 20 && availVersions.find( (v)=>v.version.startsWith( version.left( 1 ) ) ) ) {
				availVersions = availVersions.filter( (v)=>v.version.startsWith( version.left( 1 ) ) );
			}
			if( availVersions.len() > 20 && availVersions.find( (v)=>v.version.startsWith( version.left( 3 ) ) ) ) {
				availVersions = availVersions.filter( (v)=>v.version.startsWith( version.left( 3 ) ) );
			}
			if( availVersions.len() > 20 && availVersions.find( (v)=>v.version.startsWith( version.left( 5 ) ) ) ) {
				availVersions = availVersions.filter( (v)=>v.version.startsWith( version.left( 5 ) ) );
			}
			if( availVersions.len() > 20 ) {
				availVersions = availVersions.slice( 1, 20 );
			}
			throw( 'Exact version [#arguments.version#] not found for package [#arguments.slug#].', 'endpointException', 'Example versions are [#availVersions.map( function( i ){ return ' ' & i.version; } ).toList()#]' );
		}

 		// For version ranges, do a smart lookup
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
		var matches = REFindNoCase( "^([\w\-\.]+(?:\@(?!stable\b)(?!be\b)(?!x\b)[a-zA-Z][\w\-]*)?)(?:\@(.+))?$", package, 1, true );
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
	public function parseVersion( required string package, string defaultVersion='stable' ) {
		var version = defaultVersion;
		// foo@1.0.0
		var matches = REFindNoCase( "^([\w\-\.]+(?:\@(?!stable\b)(?!be\b)(?!x\b)[a-zA-Z][\w\-]*)?)(?:\@(.+))?$", package, 1, true );
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
	private function getPackage( slug, version, currentWorkingDirectory='', verbose=false ) {
		var job = wirebox.getInstance( 'interactiveJob' );
		var APIToken = getAPIToken();

		try {
			// Info
			job.addLog( "Verifying package '#slug#' in #getNamePrefixes()#, please wait..." );

			var entryData = forgebox.getEntry( slug, APIToken );

			// entrylink,createdate,lname,isactive,installinstructions,typename,version,hits,coldboxversion,sourceurl,slug,homeurl,typeslug,
			// downloads,entryid,fname,changelog,updatedate,downloadurl,title,entryrating,summary,username,description,email

			if( !entryData.isActive ) {
				throw( 'The #getNamePrefixes()# entry [#entryData.title#] is inactive.', 'endpointException' );
			}

			var satisfyingVersion = findSatisfyingVersion( slug, version, entryData );
			arguments.version = satisfyingVersion.version;
			var downloadURL = satisfyingVersion.downloadURL;

			if( !len( downloadURL ) ) {
				throw( 'No download URL provided in #getNamePrefixes()#.  Manual install only.', 'endpointException' );
			}

			// Validate the binary hash
			if( len( satisfyingVersion.binaryHash ) && satisfyingVersion.binaryHash != hash( fileReadBinary( downloadURL ), "MD5" ) ) {
				throw( 'The binary hash of the downloaded file does not match the expected hash.', 'endpointException' );
			}

			job.addLog( "Installing version [#arguments.version#]." );

			recordInstall( arguments.slug, arguments.version );

			var packageType = entryData.typeSlug;

			// Advice we found it
			job.addLog( "Verified entry in #getNamePrefixes()#: '#slug#'" );

			var strVersion = semanticVersion.parseVersion( version );

			// If the local artifact doesn't exist or it's a snapshot build, download and create it
			if( !artifactService.artifactExists( slug, version ) || ( strVersion.preReleaseID == 'snapshot' && slug != 'lucee' ) ) {
				if( downloadURL == "forgeboxStorage" ){
					downloadURL = forgebox.getStorageLocation(
						slug, arguments.version, APIToken
					);
					job.addLog( "Downloading entry from #getNamePrefixes()#." );
				}

				// Test package location to see what endpoint we can refer to.
				var endpointData = endpointService.resolveEndpoint( downloadURL, 'fakePath' );

				// Very simple check for HTTP URLs pointing to a Lex file
				if( isInstanceOf( endpointData.endpoint, 'HTTP' ) && entryData.typeslug == 'lucee-extensions' ) {
					job.addLog( "Deferring to [Lex] endpoint for #getNamePrefixes()# entry [#slug#]..." );
					var packagePath = lexEndpoint.resolvePackage( downloadURL );

					var boxJSON = packageService.readPackageDescriptorRaw( packagePath );
					boxJSON.slug = entryData.slug;
					boxJSON.name = entryData.title;
					boxJSON.version = version;
					packageService.writePackageDescriptor( boxJSON, packagePath );

				} else {
					job.addLog( "Deferring to [#endpointData.endpointName#] endpoint for #getNamePrefixes()# entry [#slug#]..." );
					var packagePath = endpointData.endpoint.resolvePackage( endpointData.package, currentWorkingDirectory, arguments.verbose );

					// Cheat for people who set a version, slug, or type in ForgeBox, but didn't put it in their box.json
					var boxJSON = packageService.readPackageDescriptorRaw( packagePath );
					if( !structKeyExists( boxJSON, 'type' ) || !len( boxJSON.type ) ) { boxJSON.type = entryData.typeslug; }
					if( !structKeyExists( boxJSON, 'slug' ) || !len( boxJSON.slug ) ) { boxJSON.slug = entryData.slug; }
					if( !structKeyExists( boxJSON, 'version' ) || !len( boxJSON.version ) ) { boxJSON.version = version; }
					packageService.writePackageDescriptor( boxJSON, packagePath );

				}

				job.addLog( "Storing download in artifact cache..." );

				// Store it locally in the artifact cache
				artifactService.createArtifact( slug, version, packagePath );

				job.addLog( "Done." );

				return packagePath;

			} else {
				job.addLog( "Package found in local artifacts!");
				var thisArtifactPath = artifactService.getArtifactPath( slug, version );
				// Defer to file endpoint
				return fileEndpoint.resolvePackage( thisArtifactPath, currentWorkingDirectory, arguments.verbose );
			}


		} catch( forgebox var e ) {

			if( e.detail contains 'The entry slug sent is invalid or does not exist' ) {
				job.addErrorLog( "#e.message#  #e.detail#" );
				throw( e.message, 'endpointException', e.detail );
			}

			job.addErrorLog( "Aww man, #getNamePrefixes()# ran into an issue.");
			job.addLog( "#e.message#  #e.detail#" );
			job.addErrorLog( "We're going to look in your local artifacts cache and see if one of those versions will work.");

			// See if there's something usable in the artifacts cache.  If so, we'll use that version.
			var satisfyingVersion = artifactService.findSatisfyingVersion( slug, version );

			if( len( satisfyingVersion ) ) {
				job.addLog( "" );
				job.addLog( "Sweet! We found a local version of [#satisfyingVersion#] that we can use in your artifacts.");
				job.addLog( "" );

				recordInstall( arguments.slug, satisfyingVersion );

				var thisArtifactPath = artifactService.getArtifactPath( slug, satisfyingVersion );
				// Defer to file endpoint
				return fileEndpoint.resolvePackage( thisArtifactPath, currentWorkingDirectory, arguments.verbose );
			} else {
				throw( 'No satisfying version found for [#version#].', 'endpointException', 'Well, we tried as hard as we can.  #getNamePrefixes()# can''t find the package and you don''t have a usable version in your local artifacts cache.  Please try another version.' );
			}

		}
	}

	function createZipFromPath( required string path ) {
		path = fileSystemUtil.resolvePath( path );
		if( !packageService.isPackage( arguments.path ) ) {
			throw(
				'Sorry but [#arguments.path#] isn''t a package.',
				'endpointException',
				'Please double check you''re in the correct directory or use "package init" to turn your directory into a package.'
			);
		}
		var boxJSON = packageService.readPackageDescriptor( arguments.path );
		var ignorePatterns = generateIgnorePatterns( boxJSON );
		var tmpPath = tempDir & hash( arguments.path );
		if ( directoryExists( tmpPath ) ) {
			directoryDelete( tmpPath, true );
		}
		directoryCreate( tmpPath );
		wirebox.getInstance( 'globber' )
			.inDirectory( arguments.path )
    		.setExcludePattern( ignorePatterns )
    		.loose()
			.copyTo( tmpPath );

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

	private array function generateIgnorePatterns( boxJSON ) {
		var ignorePatterns = [];

		var alwaysIgnores = [
			".*.swp", "._*", ".DS_Store", ".git/", ".hg/", ".svn/",
			".lock-wscript", ".wafpickle-*", "config.gypi"
		];
		var gitIgnores = readGitIgnores();
		var boxJSONIgnores = ( isArray( boxJSON.ignore ) ? boxJSON.ignore : [] );

		// this order is important for exclusions to work as expected.
		arrayAppend( ignorePatterns, alwaysIgnores, true );
		arrayAppend( ignorePatterns, gitIgnores, true );
		arrayAppend( ignorePatterns, boxJSONIgnores, true );

		return ignorePatterns;
	}

	private array function readGitIgnores() {
		var projectRoot = fileSystemUtil.resolvePath( "" );
		if ( ! fileExists( projectRoot & "/.gitignore" ) ) {
			return [];
		}
		return fileRead( projectRoot & "/.gitignore" ).listToArray(
			createObject( "java", "java.lang.System" ).getProperty( "line.separator" )
		);
	}

	/**
	* Returns the correct API token based on the name of this forgebox-based endpoint
	*/
	public function getAPIToken() {
		if( getNamePrefixes() == 'forgebox' ) {
			return configService.getSetting( 'endpoints.forgebox.APIToken', '' );
		} else {
			return configService.getSetting( 'endpoints.forgebox-#getNamePrefixes()#.APIToken', '' );
		}
	}

	/**
	* Set the default APIToken to be used for this forgebox-based endpoint
	*/
	public function setDefaultAPIToken( required string APIToken ) {
		if( getNamePrefixes() == 'forgebox' ) {
			configService.setSetting( 'endpoints.forgebox.APIToken', APIToken, false, true );
		} else {
			configService.setSetting( 'endpoints.forgebox-#getNamePrefixes()#.APIToken', APIToken, false, true );
		}
	}

	/**
	* Returns the struct of all logged in tokens based on the name of this forgebox-based endpoint
	*/
	public function getAPITokens() {
		if( getNamePrefixes() == 'forgebox' ) {
			return configService.getSetting( 'endpoints.forgebox.tokens', {} );
		} else {
			return configService.getSetting( 'endpoints.forgebox-#getNamePrefixes()#.tokens', {} );
		}
	}

	/**
	* Store a new API Token
	*/
	public function storeAPIToken( required string username, required string APIToken ) {
		if( getNamePrefixes() == 'forgebox' ) {
			configService.setSetting( 'endpoints.forgebox.APIToken', APIToken );
			configService.setSetting( 'endpoints.forgebox.tokens.#username#', APIToken );
		} else {
			configService.setSetting( 'endpoints.forgebox-#getNamePrefixes()#.APIToken', APIToken );
			configService.setSetting( 'endpoints.forgebox-#getNamePrefixes()#.tokens.#username#', APIToken );
		}
	}

	function recordInstall( slug, version ) {
		thread name="#createUUID()#" slug="#arguments.slug#", version="#arguments.version#" {
			try {
				var foo = forgeBox.recordInstall( attributes.slug, attributes.version, getAPIToken() );
			} catch( any e ) {
				logger.error( 'Error recording install', e )
			}
		}
	}


}
