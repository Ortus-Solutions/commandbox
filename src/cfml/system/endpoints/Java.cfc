/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the Java endpoint.  I interact with the AdoptOpenJDK API to get OpenJDK builds.
* I will spoof a package around the download so CommandBox doesn't try to unzip the JRE itself.
*
* Endpoint IDs are the in the format <version>_<type>_<arch>_<os>_<jvm-implementation>_<release>[:lockVersion]
* Ex: OpenJDK8_jre_x64_windows_hotspot_8u181b13
*
* <version>				: openjdk8, openjdk9, openjdk10, etc...
* <type>				: jdk, jre
* <arch>				: x64, x32, ppc64, s390x, ppc64le, aarch64
* <os>					: windows, linux, mac
* <jvm-implementation>	: hotspot, openj9
* <release>				: latest, jdk8u172, jdk8u172-b00, etc...
*
* Adding :lockVersion to the end will cause the slug reported by the package to be the full ID, not just what the user typed
*
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
	property name='ConfigService'			inject='ConfigService';
	property name='artifactService'			inject='artifactService';
	property name='filesystemUtil'			inject='fileSystem';
	property name="folderEndpoint"			inject="commandbox.system.endpoints.Folder";
	property name="PackageService"			inject="packageService";

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'java' );
		return this;
	}

	public string function resolvePackage( required string package, boolean verbose=false ) {
		var lockVersion = false;
		if( package.right( 12 ) == ':lockVersion' ) {
			var lockVersion = true;
			package = package.replace( ':lockVersion', '' );
		}
		var packageFullName = getDefaultName( package );
		var job = wirebox.getInstance( 'interactiveJob' );
		var folderName = tempDir & '/' & 'temp#createUUID()#';
		var folderName2 = tempDir & '/' & 'temp#createUUID()#';

		var javaDetails = parseDetails( package );
		
		// Turn it into the maven-style semver range [11,12)  which is the equiv of >= 11 && < 12 thus getting 11.x
		var thisVersionNum = replaceNoCase( javaDetails.version, 'openjdk', '' );
		var thisVersion = '[#thisVersionNum#,#thisVersionNum+1#)';
		var APIURLInfo = 'https://api.adoptopenjdk.net/v3/assets/version/#encodeForURL( thisVersion )#?page_size=1000&release_type=ga&vendor=adoptopenjdk&project=jdk&heap_size=normal&jvm_impl=#encodeForURL( javaDetails['jvm-implementation'] )#&os=#encodeForURL( javaDetails.os )#&architecture=#encodeForURL( javaDetails.arch )#&image_type=#encodeForURL( javaDetails.type )#';
		
		if( javaDetails.release.len() && javaDetails.release != 'latest' ) {
			var APIURL = 'https://api.adoptopenjdk.net/v3/binary/version/#encodeForURL( javaDetails.release )#/#encodeForURL( javaDetails.os )#/#encodeForURL( javaDetails.arch )#/#encodeForURL( javaDetails.type )#/#encodeForURL( javaDetails['jvm-implementation'] )#/normal/adoptopenjdk';
		} else {
			var APIURL = 'https://api.adoptopenjdk.net/v3/binary/latest/#thisVersionNum#/ga/#encodeForURL( javaDetails.os )#/#encodeForURL( javaDetails.arch )#/#encodeForURL( javaDetails.type )#/#encodeForURL( javaDetails['jvm-implementation'] )#/normal/adoptopenjdk';
		}
		
		job.addLog( "Installing [#package#]" );
		job.addLog( "Java version:              #javaDetails.version#" );
		job.addLog( "Java type:                 #javaDetails.type#" );
		job.addLog( "Java arch:                 #javaDetails.arch#" );
		job.addLog( "Java os:                   #javaDetails.os#" );
		job.addLog( "Java jvm-implementation:   #javaDetails['jvm-implementation']#" );
		job.addLog( "Java release:              #javaDetails.release#" );

		if( artifactService.artifactExists( 'OpenJDK', packageFullName ) ) {
			job.addLog( "Lucky you, we found this version of Java in local artifacts!" );
			return serveFromArtifacts( package, packageFullName, lockVersion );
		}

		job.addLog( 'Hitting the AdoptOpenJDK API to find your download.' );
		job.addLog( APIURLInfo );


		// Get JSON info about the download. If this URL doesn't work, neither will the binary one
		http
			url="#APIURLInfo#"
			timeout=30
			throwOnError=false
			proxyServer="#ConfigService.getSetting( 'proxy.server', '' )#"
			proxyPort="#ConfigService.getSetting( 'proxy.port', 80 )#"
			proxyUser="#ConfigService.getSetting( 'proxy.user', '' )#"
			proxyPassword="#ConfigService.getSetting( 'proxy.password', '' )#"
			result="local.artifactResult";

		var notFound = false;
		if( local.artifactResult.status_code == 200 && isJSON( local.artifactResult.fileContent ) ) {
			var artifactJSON = deserializeJSON( local.artifactResult.fileContent );
			
			// If we have a release, we need to filter it now
			if( javaDetails.release.len() && javaDetails.release != 'latest' ) {
				artifactJSON = artifactJSON.filter( (release)=>release.release_name==javaDetails.release );
			}
			
			if( !artifactJSON.len() ) {
				notFound = true;
			}
		} else {
			notFound = true;
		} 
		
		if( notFound ){
			var validReleases = 'unknown';

			try {
				// Do a quick peek at the API to see if we can get results back without the release name.				
				
				var thisVersionNum = replaceNoCase( javaDetails.version, 'openjdk', '' );
				// Turn it into the maven-style semver range [11,12)
				// which is the equiv of >= 11 && < 12 thus getting 11.x
				var thisVersion = '[#thisVersionNum#,#thisVersionNum+1#)';
				
				var APIURLCheck = 'https://api.adoptopenjdk.net/v3/assets/version/#encodeForURL(thisVersion )#?release_type=ga&vendor=adoptopenjdk&project=jdk&heap_size=normal&jvm_impl=#encodeForURL( javaDetails['jvm-implementation'] )#&os=#encodeForURL( javaDetails.os )#&architecture=#encodeForURL( javaDetails.arch )#&image_type=#encodeForURL( javaDetails.type )#';

				http
					url="#APIURLCheck#"
					timeout=30
					throwOnError=false
					proxyServer="#ConfigService.getSetting( 'proxy.server', '' )#"
					proxyPort="#ConfigService.getSetting( 'proxy.port', 80 )#"
					proxyUser="#ConfigService.getSetting( 'proxy.user', '' )#"
					proxyPassword="#ConfigService.getSetting( 'proxy.password', '' )#"
					result="local.artifactResult";

				if( local.artifactResult.status_code == 200 && isJSON( local.artifactResult.fileContent ) ) {
					// If we got a valid reply back, gather up a list of the release names that were returned.
					var artifactJSON = deserializeJSON( local.artifactResult.fileContent );
					validReleases = artifactJSON
						.map( function( release ) {
							return release.release_name;
						} )
						.tolist( ', ' );
				}

			} catch ( any var e ) {
				job.addErrorLog( 'Error peeking at the API to try and find some valid releases.' );
				job.addErrorLog( e.message );
				job.addErrorLog( e.detail );
			}
			var message = 'This specific Java version doesn''t seem to exist.  Valid [#javaDetails.version#] releases are [#validReleases#].';
			job.addErrorLog( message );

			// Before we give up, check artifacts for a downloaded version that might work
			// Ideally I'd only do this for catastropic errors, but the AdoptOpenJDK API doesn't really allow me to
			// tell the difference since it pretty much just pukes non-JSON if it can't find what I was looking for
			var artifactJDKs = artifactService.listArtifacts( 'OpenJDK' );
			if( artifactJDKs.keyExists( 'OpenJDK' ) ) {
				job.addWarnLog( 'Digging through your artifacts to see if we can find something useful before we give up...' );
				// Trying to get the later ones first, but this approach is a little flakey
				var artifactVersions = artifactJDKs.OpenJDK.sort( 'text', 'desc' );
				var partialUserVersion = '#javaDetails.version#_#javaDetails.type#_#javaDetails.arch#_#javaDetails.os#_#javaDetails[ 'jvm-implementation' ]#'.lcase();
				for( var thisVer in artifactVersions ) {
					if( thisVer.lcase().startsWith( partialUserVersion ) ) {
						job.addLog( "Looks like you already have [#thisVer#] downloaded. Using it instead." );
						return serveFromArtifacts( package, thisVer, lockVersion );
					}
				}
			}

			throw( message, 'endpointException' );
		}

		// Sometimes the API gives me back a struct, sometimes I get an array of structs. ¯\_(ツ)_/¯
		if( isArray( artifactJSON ) && arraylen( artifactJSON ) ) {
			artifactJSON = artifactJSON[ 1 ];
		}

		if( !isStruct( artifactJSON ) || !artifactJSON.keyExists( 'binaries' ) || !isArray( artifactJSON.binaries ) || !artifactJSON.binaries.len() ) {
			throw( 'This specific Java version doesn''t seem to exist.  Please try another.', 'endpointException' );
		}

		// worthless version that's just "11", etc
		// artifactjson.binaries[ 1 ].version
		javaDetails.release = artifactJSON.release_name;
		var version = getDefaultNameFromStruct( javaDetails );
		job.addLog( 'Exact version is [#version#]' );
		// Now that we know exactly what we're going to get, try the artifacts one more time
		if( artifactService.artifactExists( 'OpenJDK', version ) ) {
			job.addLog( "Lucky you, we found this version of Java in local artifacts!" );
			return serveFromArtifacts( package, version, lockVersion );
		}

		directoryCreate( folderName );
		var tmpFilePath = folderName & '/' & package & ( javaDetails.os == 'windows' ? '.zip' : '.tar.gz' );

		try {
			// Download File
			var result = progressableDownloader.download(
				APIURL, // URL to package
				tmpFilePath, // Place to store it locally
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

		directoryCreate( folderName2 );

		// Extract the archive into a temp folder
		if( tmpFilePath.endsWith( '.zip' ) ) {
			zip action="unzip" file="#tmpFilePath#" destination="#folderName2#" overwrite="false";
		} else {
			filesystemUtil.extractTarGz( tmpFilePath, '#folderName2#' );
		}

		// Clean up original tmp dir
		directoryDelete( folderName, true );

		// We need to find the first folder that was INSIDE the archive
		var folders = directoryList( path="#folderName2#", type="dir", listInfo="name" );
		if( !folders.len() ) {
			throw( 'The downloaded archive did not contain a folder as expected.', 'endpointException', APIURL );
		}
		var finalPackageRoot = '#folderName2#/#folders[ 1 ]#'

		if( javaDetails.os == 'mac' ) {
			finalPackageRoot &= '/Contents/Home';
		}
		var fullBoxJSONPath = '#finalPackageRoot#/box.json';

		// Spoof a box.json so this looks like a package
		var boxJSON = {
			'name' : ( lockVersion ? version : package ),
			'slug' : ( lockVersion ? version : package ),
			'version' : version,
			'location' : 'java:#( lockVersion ? version : package )#',
			'type' : 'projects',
			'java' : artifactJSON.binaries[ 1 ],
			'author' : 'AdoptOpenJDK',
			'projectURL' : 'https://adoptopenjdk.net/',
			'homepage' : 'https://adoptopenjdk.net/'
		};
		JSONService.writeJSONFile( fullBoxJSONPath, boxJSON );

		// Store in artifacts for next time
		artifactService.createArtifactFromFolder( 'OpenJDK', version, finalPackageRoot );

		// Here is where our alleged so-called "package" lives.
		return finalPackageRoot;

	}

	public function getDefaultName( required string package ) {
		return getDefaultNameFromStruct( parseDetails( package ) );
	}

	function getDefaultNameFromStruct( required struct javaDetails ) {
		return '#javaDetails.version#_#javaDetails.type#_#javaDetails.arch#_#javaDetails.os#_#javaDetails[ 'jvm-implementation' ]#_#javaDetails.release#';
	}

	public function getUpdate( required string package, required string version, boolean verbose=false ) {
		// For now we'll say it's never out of date
		// We can potentially hit the API and look for a newer version, but there's
		// no concept of semver or version ranges implemented yet to this endpoint
		var result = {
			isOutdated = false,
			version = 'unknown'
		};

		return result;
	}

	/**
	 * Take a string like OpenJDK8_jre_x64_windows_hotspot_8u181b13
	 * and parse out all the details
	 */
	function parseDetails( required string ID ) {

			/*
			* <version>				: openjdk8, openjdk9, openjdk10, etc...
			* <type>				: jdk, jre
			* <arch>				: x64, x32, ppc64, s390x, ppc64le, aarch64
			* <os>					: windows, linux, mac
			* <jvm-implementation>	: hotspot, openj9
			* <release>				: latest, jdk8u172, jdk8u172-b00, etc...
			*/
			ID = ID.lCase();

			var results = {
				version : '',
				type : 'jre',
				arch : server.java.archModel contains 32 ? 'x32' : 'x64',
				os : '',
				'jvm-implementation' : ( ID.findNoCase( 'openj9' ) ? 'openj9' : 'hotspot' ),
				release : 'latest'
			};

			if( fileSystemUtil.isMac() ) {
				results.os = 'mac';
			} else if( fileSystemUtil.isLinux() ) {
				results.os = 'linux';
			} else {
				results.os = 'windows';
			}

			var tokens = ID.listToArray( '_' );
			var first = true;
			for( var token in tokens ) {
				// First token must be version
				if( first ) {
					results.version = token;
					first =  false;
				} else {
					// type
					if( listFindNoCase( 'jre,jdk', token) ) {
						results.type = token;
						continue;
					}
					// arch
					if( listFindNoCase( 'x64,x32,ppc64,s390x,ppc64le,aarch64', token) ) {
						results.arch = token;
						continue;
					}
					// OS
					if( listFindNoCase( 'windows,linux,mac,aix', token) ) {
						results.os = token;
						continue;
					}
					// jvm-implementation
					if( listFindNoCase( 'hotspot,openj9', token) ) {
						results[ 'jvm-implementation' ] = token;
						continue;
					}
					// release
					if( token == 'latest' || token.lcase().startsWith( 'jdk' ) ) {
						results.release = token;
						continue;
					}
					// release, part 2
					if( token.lcase().startsWith( 'openj' ) ) {
						results.release &= ( '_' & token );
						continue;
					}
					throw( message='Unknown token [#token#] in Java install slug [#ID#]', detail='Please use "java search" to find valid java install slugs.', type='endpointException' );
				}
			}

		return results;

	}

	function serveFromArtifacts( package, version, lockVersion ) {
		var job = wirebox.getInstance( 'interactiveJob' );
		var folderName = tempDir & '/' & 'temp#createUUID()#';

		directoryCreate( folderName );
		zip action="unzip" file="#artifactService.getArtifactPath( 'OpenJDK', version )#" destination="#folderName#";

		// Update the box.json to match the name we're using since different slugs can all point to the same "normalized" name
		var boxJSON = packageService.readPackageDescriptorRaw( folderName );
		boxJSON.name = ( lockVersion ? version : package );
		boxJSON.slug = ( lockVersion ? version : package );
		boxJSON.location = 'java:' & ( lockVersion ? version : package );
		packageService.writePackageDescriptor( boxJSON, folderName );

		return folderEndpoint.resolvePackage( folderName );
	}

			/*
			jdk-11+28
			jdk-11.0.1+13
			jdk-10.0.1+10
			jdk-10.0.2+13_openj9-0.9.0
			jdk-9+181
			jdk-9.0.4+11
			jdk-9.0.4+12_openj9-0.9.0
			jdk8u162-b12_openj9-0.8.0
			jdk8u172-b11
		*/

}
