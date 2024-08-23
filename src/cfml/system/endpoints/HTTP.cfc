/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the HTTP endpoint.  I get packages from an HTTP URL.
*/
component accessors=true implements="IEndpoint" singleton {

	// DI
	property name="consoleLogger"			inject="logbox:logger:console";
	property name="tempDir" 				inject="tempDir@constants";
	property name="artifactService" 		inject="ArtifactService";
	property name="fileEndpoint"			inject="commandbox.system.endpoints.TempFile";
	property name="progressableDownloader" 	inject="ProgressableDownloader";
	property name="progressBar" 			inject="ProgressBar";
	property name="CR" 						inject="CR@constants";
	property name='wirebox'					inject='wirebox';
	property name="semanticVersion"			inject="provider:semanticVersion@semver";
	property name='semverRegex'				inject='semverRegex@constants';
	property name='configService'			inject='configService';

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'HTTP' );
		return this;
	}

	public string function resolvePackage( required string package, string currentWorkingDirectory="", boolean verbose=false ) {
		// Defer to file endpoint
		return fileEndpoint.resolvePackage(
			resolvePackageZip( package, arguments.verbose ),
			currentWorkingDirectory,
			arguments.verbose
		);

	}

	public string function resolvePackageZip( required string package, boolean verbose=false ) {
		var binaryHash = '';
		//  Check if a hash is in the URL and if so, strip it out
		if( package contains '##' ) {
			package = package.listFirst( '##' );
			binaryHash = package.listLast( '##' );
		}

		if( configService.getSetting( 'offlineMode', false ) ) {
			throw( 'Can''t download [#getNamePrefixes()#:#package#], CommandBox is in offline mode.  Go online with [config set offlineMode=false].', 'endpointException' );
		}

		var job = wirebox.getInstance( 'interactiveJob' );

		var fileName = 'temp#createUUID()#.zip';
		var fullPath = tempDir & '/' & fileName;

		job.addLog( "Downloading [#getNamePrefixes().replaceNoCase( '+cached', '' ) & ':' & package#]" );

		try {
			// Download File
			var result = progressableDownloader.download(
				getNamePrefixes().replaceNoCase( '+cached', '' ) & ':' & package, // URL to package
				fullPath, // Place to store it locally
				function( status ) {
					progressBar.update( argumentCollection = status );
				},
				function( newURL ) {
					job.addLog( "Redirecting to: '#arguments.newURL#'..." );
				}
			);
			
			// Validate the binary hash
			if( len( binaryHash ) && binaryHash != hash( fileReadBinary( fullPath ), "MD5" ) ) {
				throw( 'The binary hash of the downloaded file does not match the expected hash.', 'endpointException' );
			}
		} catch( UserInterruptException var e ) {
			if( fileExists( fullPath ) ) { fileDelete( fullPath ); }
			rethrow;
		} catch( Any var e ) {
			if( fileExists( fullPath ) ) { fileDelete( fullPath ); }
			throw( '#e.message##CR##e.detail#', 'endpointException' );
		};

		return fullPath;
	}

	public function getDefaultName( required string package ) {

		// strip query string
		var baseURL = listFirst( arguments.package, '?' );

		// GitHub zip downloads tend to be called useless things like "master"
		// https://github.com/Ortus-Solutions/commandbox-docs/archive/master.zip
		if( baseURL contains 'github.com' ) {
			// Ortus-Solutions/commandbox-docs/archive/master.zip
			var path = mid( baseURL, findNoCase( 'github.com', baseURL ) + 10, len( baseURL ) );
			if( listLen( path, '/' ) >= 2 ) {
				// commandbox-docs
				return listGetAt( path, 2, '/' );
			}
		}

		// Find last segment of URL (may or may not be a file)
		var fileName = listLast( baseURL, '/' );

		// Check for file extension in URL
		var fileNameListLen = listLen( fileName, '.' );
		if( fileNameListLen > 1 && listLast( fileName, '.' ) == 'zip' ) {
			return listDeleteAt( fileName, fileNameListLen, '.' );
		}
		return reReplaceNoCase( arguments.package, '[^a-zA-Z0-9]', '', 'all' );
	}

	public function getUpdate( required string package, required string version, boolean verbose = false ) {
		// If we're coming through the http+cached or https+cached endpoint, strip this out
		package = package.replaceNoCase( '+cached', '' );
		// Check to see if a semver exists in the URL and if so use that
		var versionMatch = reMatch( semverRegex, package.reReplaceNoCase( '(https?:)?//', '' ).listRest( '/\' ) );

		if ( versionMatch.len() ) {
			return {
				isOutdated: semanticVersion.isNew( current = arguments.version, target = versionMatch.last() ),
				version: versionMatch.last()
			};
		}

		// Did not find a version in the URL so assume package is outdated
		return {
			isOutdated: true,
			version: 'unknown'
		};
	}

}
