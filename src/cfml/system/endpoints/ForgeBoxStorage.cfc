/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the ForgeBox endpoint.  I wrap CFML's coolest package repository EVER!
*/
component accessors="true" implements="IEndpoint" singleton {

	// DI
	property name="CR" 					   inject="CR@constants";
	property name="consoleLogger"		   inject="logbox:logger:console";
	property name="forgeBox" 			   inject="ForgeBox";
	property name="tempDir" 			   inject="tempDir@constants";
	property name="semanticVersion"		   inject="provider:semanticVersion@semver";
	property name="progressableDownloader" inject="ProgressableDownloader";
	property name="progressBar" 		   inject="ProgressBar";
	property name="configService" 		   inject="configService";
	property name="fileEndpoint"		   inject="commandbox.system.endpoints.File";

	// Properties
	property name="namePrefixes" type="string";

	/**
	 * Constructor
	 */
	function init() {
		setNamePrefixes( 'forgeboxStorage' );
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

		var fileName = 'temp#randRange( 1, 1000 )#.zip';
		var fullPath = tempDir & '/' & fileName;

		consoleLogger.info( "Downloading #package# from ForgeBox Pro" );

		try {
			var APIToken = configService.getSetting( 'endpoints.forgebox.APIToken', '' );
			var uri = forgebox.getStorageLocation( slug, version, APIToken );

			// Download File
			var result = progressableDownloader.download(
				uri, // URL to package
				fullPath, // Place to store it locally
				function( status ) {
					progressBar.update( argumentCollection = status );
				},
				function( newURL ) {
					consoleLogger.info( "Redirecting to: '#arguments.newURL#'..." );
				}
			);
		} catch( Any var e ) {
			throw( '#e.message##CR##e.detail#', 'endpointException' );
		};

		// Defer to file endpoint
		return fileEndpoint.resolvePackage( fullPath, arguments.verbose );
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

}
