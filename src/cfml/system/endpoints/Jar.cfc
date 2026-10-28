/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the Jar endpoint.  I get bare jar files from an HTTP URL.
* I will spoof a package around the jar so CommandBox doesn't try to unzip the jar itself.
*/
component accessors=true implements="IEndpoint" singleton {

	// DI
	property name="consoleLogger"			inject="logbox:logger:console";
	property name="tempDir" 				inject="tempDir@constants";
	property name="progressableDownloader" 	inject="ProgressableDownloader";
	property name="progressBar" 			inject="ProgressBar";
	property name="CR" 						inject="CR@constants";
	property name='JSONService'				inject='JSONService';
	property name='wirebox'					inject='wirebox';
	property name='S3Service'				inject='S3Service';
	property name='configService'			inject='configService';

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'jar' );
		variables.defaultVersion = '0.0.0';
		return this;
	}

	public string function resolvePackage( required string package, string currentWorkingDirectory="", boolean verbose=false ) {

		if( configService.getSetting( 'offlineMode', false ) ) {
			throw( 'Can''t download [#getNamePrefixes()#:#package#], CommandBox is in offline mode.  Go online with [config set offlineMode=false].', 'endpointException' );
		}

		var job = wirebox.getInstance( 'interactiveJob' );
		var folderName = tempDir & '/' & 'temp#createUUID()#';
		var fullJarPath = folderName & '/' & getDefaultName( package ) & '.jar';
		var fullBoxJSONPath = folderName & '/box.json';
		directoryCreate( folderName );

		job.addLog( "Downloading [#package#]" );

		var packageUrl = package.startsWith('s3://') ? S3Service.generateSignedURL(package, verbose) : package;

		try {
			// Download File
			var result = progressableDownloader.download(
				packageUrl, // URL to package
				fullJarPath, // Place to store it locally
				function( status ) {
					progressBar.update( argumentCollection = status );
				},
				function( newURL ) {
					job.addLog( "Redirecting to: '#arguments.newURL#'..." );
				}
			);
		} catch( UserInterruptException var e ) {
			directoryDelete( folderName, true );
			rethrow;
		} catch( Any var e ) {
			directoryDelete( folderName, true );
			throw( '#e.message##CR##e.detail#', 'endpointException' );
		};


		// Spoof a box.json so this looks like a package
		var boxJSON = {
			'name' : '#getDefaultName( package )#.jar',
			'slug' : getDefaultName( package ),
			'version' : guessVersionFromURL( package ),
			'location' : 'jar:#package#',
			'type' : 'jars'
		};
		JSONService.writeJSONFile( fullBoxJSONPath, boxJSON );

		// Here is where our alleged so-called "package" lives.
		return folderName;

	}

	public function getDefaultName( required string package ) {

		// Strip protocol and host to reveal just path and query string
		package = package.reReplaceNoCase( '^([\w:]+)?//.*?/', '' );

		// Check and see if the name of the jar appears somewhere in the URL and use that as the package name
		// https://search.maven.org/remotecontent?filepath=jline/jline/3.0.0.M1/jline-3.0.0.M1.jar
		// https://site.com/path/to/package-1.0.0.jar

		// If we see /foo.jar or name=foo.jar or ?foo.jar
		if( package.reFindNoCase( '[/\?=](.*\.jar)' ) ) {
			// Then strip the name and remove extension
			// Note the first .* is greedy so in the case of
			// https://site.com/path/to/file.jar?name=custom.jar
			// the regex will extract the last match, i.e. "custom"
			return package.reReplaceNoCase( '.*[/\?=](.*\.jar).*', '\1' ).left( -4 );
		}

		// We give up, so just make the entire URL a slug
		return reReplaceNoCase( package, '[^a-zA-Z0-9]', '', 'all' );
	}

	public function getUpdate( required string package, required string version, boolean verbose=false ) {
		packageVersion = guessVersionFromURL( package );
		// No version could be determined from package URL
		if( packageVersion == defaultVersion ) {
			return {
				isOutdated = true,
				version = 'unknown'
			};
		// Our package URL has a version and it's the same as what's installed
		} else if( version == packageVersion ) {
			return {
				isOutdated = false,
				version = packageVersion
			};
		// our package URL has a versiion and it's not what's installed
		} else {
			return {
				isOutdated = true,
				version = packageVersion
			};
		}
	}

	private function guessVersionFromURL( required string package ) {
		var version = package;
		if( version contains '/' ) {
			var version = version
				.reReplaceNoCase( '^([\w:]+)?//', '' )
				.listRest( '/\' );
		}
		if( version.refindNoCase( '.*([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}).*' ) ) {
			version = version.reReplaceNoCase( '.*([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}).*', '\1' );
		} else {
			version = defaultVersion;
		}
		return version;
	}

}
