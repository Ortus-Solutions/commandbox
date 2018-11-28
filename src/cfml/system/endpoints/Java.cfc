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
* Endpoint IDs are the in the format <version>_<type>_<arch>_<os>_<jvm-implementation>_<release>
* Ex: OpenJDK8_jre_x64_windows_hotspot_8u181b13
*
* <version>				: openjdk8, openjdk9, openjdk10, etc...
* <type>				: jdk, jre
* <arch>				: x64, x32, ppc64, s390x, ppc64le, aarch64
* <os>					: windows, linux, mac
* <jvm-implementation>	: hotspot, openj9
* <release>				: latest, jdk8u172, jdk8u172-b00, etc...
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
	property name="fileEndpoint"			inject="commandbox.system.endpoints.File";

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'java' );
		return this;
	}

	public string function resolvePackage( required string package, boolean verbose=false ) {
		var job = wirebox.getInstance( 'interactiveJob' );
		var folderName = tempDir & '/' & 'temp#randRange( 1, 1000 )#';
		directoryCreate( folderName );

		var javaDetails = parseDetails( package );
		var APIURL = 'https://api.adoptopenjdk.net/v2/binary/releases/#javaDetails.version#?openjdk_impl=#javaDetails['jvm-implementation']#&os=#javaDetails.os#&arch=#javaDetails.arch#&release=#javaDetails.release#&type=#javaDetails.type#';

		job.addLog( "Installing [#package#]" );
		job.addLog( "Java version:              #javaDetails.version#" );
		job.addLog( "Java type:                 #javaDetails.type#" );
		job.addLog( "Java arch:                 #javaDetails.arch#" );
		job.addLog( "Java os:                   #javaDetails.os#" );
		job.addLog( "Java jvm-implementation:   #javaDetails['jvm-implementation']#" );
		job.addLog( "Java release:              #javaDetails.release#" );
		
		// Crap way of getting version and only gets major number right now.
		// Alternate method would be to parse all the possible release names:
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
		var version = javaDetails.version.replaceNoCase( 'openjdk', '' );
		
		if( artifactService.artifactExists( package, version ) ) {
			job.addLog( "Lucky you, we found this version of Java in local artifacts!" );
			return fileEndpoint.resolvePackage( artifactService.getArtifactPath( package, version ) );
		}

		var APIURLInfo = APIURL.replace( '/binary/', '/info/' );
		job.addLog( APIURLInfo );


		// Get JSON info about the download. If this URL doesn't work, neither will the binary one
		http
			url="#APIURLInfo#"
			throwOnError=false
			proxyServer="#ConfigService.getSetting( 'proxy.server', '' )#"
			proxyPort="#ConfigService.getSetting( 'proxy.port', 80 )#"
			proxyUser="#ConfigService.getSetting( 'proxy.user', '' )#"
			proxyPassword="#ConfigService.getSetting( 'proxy.password', '' )#"
			result="local.artifactResult";

		if( local.artifactResult.status_code == 200 && isJSON( local.artifactResult.fileContent ) ) {
			var artifactJSON = deserializeJSON( local.artifactResult.fileContent );
		} else {
			var validReleases = 'unknown';
			
			try {
				// Do a quick peek at the API to see if we can get results back without the release name.
				var APIURLCheck = 'https://api.adoptopenjdk.net/v2/info/releases/#javaDetails.version#?openjdk_impl=#javaDetails['jvm-implementation']#&os=#javaDetails.os#&arch=#javaDetails.arch#&type=#javaDetails.type#';
			
				http
					url="#APIURLCheck#"
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
		
			throw( 'This specific Java version doesn''t seem to exist.  Valid [#javaDetails.version#] releases are [#validReleases#].', 'endpointException' );
		}
		
		// Sometimes the API gives me back a struct, sometimes I get an array of structs. ¯\_(ツ)_/¯
		if( isArray( artifactJSON ) && arraylen( artifactJSON ) ) {
			artifactJSON = artifactJSON[ 1 ];
		}
				
		if( !isStruct( artifactJSON ) || !artifactJSON.keyExists( 'binaries' ) || !isArray( artifactJSON.binaries ) || !artifactJSON.binaries.len() ) {
			throw( 'This specific Java version doesn''t seem to exist.  Please try another.', 'endpointException' );
		}

		var releaseName = artifactJSON.release_name;
		var version = artifactJSON.binaries[ 1 ].version;
		
		var tmpFilePath = folderName & '/' & getDefaultName( package ) & ( javaDetails.os == 'windows' ? '.zip' : '.tar.gz' );

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
		} catch( Any var e ) {
			throw( '#e.message##CR##e.detail#', 'endpointException' );
		};

		// Extract the archive into a temp folder
		if( tmpFilePath.endsWith( '.zip' ) ) {
			zip action="unzip" file="#tmpFilePath#" destination="#folderName#/tmp" overwrite="false";
		} else {
			filesystemUtil.extractTarGz( tmpFilePath, '#folderName#/tmp' );
		}

		// We need to find the first folder that was INSIDE the archive
		var folders = directoryList( path="#folderName#/tmp", type="dir", listInfo="name" );
		if( !folders.len() ) {
			throw( 'The downloaded archive did not contain a folder as expected.', 'endpointException', APIURL );
		}
		var finalPackageRoot = '#folderName#/tmp/#folders[ 1 ]#'
		var fullBoxJSONPath = '#finalPackageRoot#/box.json';

		// Spoof a box.json so this looks like a package
		var boxJSON = {
			'name' : getDefaultName( package ),
			'slug' : getDefaultName( package ),
			'version' : version,
			'location' : 'java:#package#',
			'type' : 'projects',
			'java' : artifactJSON.binaries[ 1 ]
		};
		JSONService.writeJSONFile( fullBoxJSONPath, boxJSON );

		// Store in artifacts for next time
		artifactService.createArtifactFromFolder( package, version, finalPackageRoot );

		// Here is where our alleged so-called "package" lives.
		return finalPackageRoot;

	}

	public function getDefaultName( required string package ) {
		return package;
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
					
				}
			}

		return results;
	
	}

}
