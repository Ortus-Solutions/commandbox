/**
 * Search for available versions of java for you to use
 * .
 * {code:bash}
 * server java search
 * {code}
 *
 * version is required for the API to work so you can only search for builds of the same major version at a time.
 * .
 * {code:bash}
 * server java search version=8
 * server java search version=9
 * server java search version=10
 * server java search version=11
 * {code}
 *
 * version, jvm, arch, os, and type are defaulted automatically based on your local PC.
 * You can search across all options by passing in blank for each param
 * .
 * {code:bash}
 * server java search jvm= arch= type= os=
 * {code}
 *
 * Or get the raw JSON as it was returned from the API
 * {code:bash}
 * server java search --JSON
 * {code}
 *
 * If a failing HTTP status code is received from the API, this command will return an exit code of 1
 *
 **/
component aliases='java search' {

	// DI
	property name="javaService"		inject="JavaService";
	property name="packageService"	inject="PackageService";
	property name="java"			inject="commandbox.system.endpoints.java";

	/**
	* @version Major OpenJDK version such as "11" or a maven-style semver range
	* @version.optionsUDF versionComplete
	* @jvm The JVM Implementation such as "hotspot" or "openj9"
	* @jvm.options hotspot,openj9
	* @os The operating system. Windows, linux, or mac
	* @os.options windows,linux,mac
	* @arch CPU Architecture such as x64 or x32
	* @arch.options x64, x32, ppc64, s390x, ppc64le, aarch64
	* @type Whether the build is a JRE or JDK.
	* @type.options jdk,jre
	* @release A specific release name or the word "latest"
	* @release.options latest
	* @release.JSON Output the RAW JSON received from the remote API
	*/
	function run(
		version,
		jvm = 'hotspot',
		os,
		arch = javaService.getCurrentCPUArch(),
		type = 'jre',
		release = 'latest',
		boolean JSON = false
	){

		// If there is no version passed but we have a release, default the version based on the release.
		if( isNull( version ) && release.len() && release != 'latest' ) {
			// Java 8 releases look like jdk8u265-b01
			if( release contains 'jdk8' ) {
				version = 8;
			// Java 9+ releases look like jdk-11.0.8+10
			} else {
				version = listFirst( release.replaceNoCase( 'jdk-', '' ), '.' );
			}
		// If there is no version and no release, hit the API to get the latest LTS version
		} else if( isNull( version ) || !len( version ) ) {
			// Until Adobe and Lucee support Java 17, we'll keep this defaulting to Java 11-- the current LTS release supported by CF engines.
			version = 11;
			/*
			http
				url="https://api.adoptium.net/v3/info/available_releases"
				throwOnError=false
				timeout=5
				proxyServer="#ConfigService.getSetting( 'proxy.server', '' )#"
				proxyPort="#ConfigService.getSetting( 'proxy.port', 80 )#"
				proxyUser="#ConfigService.getSetting( 'proxy.user', '' )#"
				proxyPassword="#ConfigService.getSetting( 'proxy.password', '' )#"
				result="local.artifactResult";

			var fileContent = toString( local.artifactResult.fileContent );
			if( local.artifactResult.status_code == 200 && isJSON( fileContent ) ) {
				var artifactJSON = deserializeJSON( fileContent );
				version = artifactJSON.most_recent_lts;
			// If the API didn't work, just use this
			} else {
				version = 11;
			}
			*/
		}

		// Backwards compat so 8 so the same as openjdk8
		version = replaceNoCase( version, 'openjdk', '' );
		// If we only have a number like 11
		if( !reFind( '[^0-9]', version ) ) {
			// Turn it into the maven-style semver range [11,12) which is the equiv of >= 11 && < 12 thus getting 11.x
			version = '[#version#,#version+1#)';
		}

		if( isNull( os) ) {
			if( fileSystemUtil.isMac() ) {
				os = 'mac';
			} else if( fileSystemUtil.isLinux() ) {
				os = 'linux';
			} else {
				os = 'windows';
			}
		}

		var APIURLCheck = 'https://api.adoptium.net/v3/assets/version/#encodeForURL(version)#?page_size=100&release_type=ga&vendor=eclipse&project=jdk&heap_size=normal';

		if( jvm.len() ) {
			APIURLCheck &= '&jvm_impl=#encodeForURL( jvm )#';
		}
		if( os.len() ) {
			APIURLCheck &= '&os=#encodeForURL( os )#';
		}
		if( arch.len() ) {
			APIURLCheck &= '&architecture=#encodeForURL( arch )#';
		}
		if( type.len() ) {
			APIURLCheck &= '&image_type=#encodeForURL( type )#';
		}

		http
			url="#APIURLCheck#"
			timeout=20
			throwOnError=false
			proxyServer="#ConfigService.getSetting( 'proxy.server', '' )#"
			proxyPort="#ConfigService.getSetting( 'proxy.port', 80 )#"
			proxyUser="#ConfigService.getSetting( 'proxy.user', '' )#"
			proxyPassword="#ConfigService.getSetting( 'proxy.password', '' )#"
			result="local.artifactResult";

		var fileContent = toString( local.artifactResult.fileContent );
		if( local.artifactResult.status_code == 404 ) {
			var artifactJSON = [];
		} else if( local.artifactResult.status_code == 200 && isJSON( fileContent ) ) {
			var artifactJSON = deserializeJSON( fileContent );

			// If we have a release, we need to filter it now
			if( release.len() && release != 'latest' ) {
				artifactJSON = artifactJSON.filter( (thisRelease)=>thisRelease.release_name==release );
			}
		} else {
			print.redLine( fileContent.left( 100 ) );
			error( 'There was an error hitting the API.  [#local.artifactResult.status_code#]' );
		}

		// Sometimes the API gives me back a struct, sometimes I get an array of structs. ¯\_(ツ)_/¯
		if( isStruct( artifactJSON ) ) {
			artifactJSON = [ artifactJSON ];
		}

		if( JSON ) {
			print.line( artifactJSON );
			return;
		} else {
			print
				.line()
				.line( 'Hitting API URL:' )
				.indentedline( APIURLCheck )
				.line()
				.line();
		}

		if( !artifactJSON.len() ) {
			print.redLine( 'No matching Java versions found for your search criteria' );
			return;
		}

		for( var javaVer in artifactJSON ) {
			var headerWidth = ('Release Name: ' & javaVer.release_name & '  Release Date: ' & dateFormat( javaVer.timestamp )).len()+4;
			var colWidth = int( ( headerWidth/4 )-1 );
			var lastColWidth = headerWidth - ( (colWidth*4)+5 ) + colWidth;
			print
				.boldLine( repeatString( '-', headerWidth ) )
				.boldText( '| Release Name: ' ).boldCyanText( javaVer.release_name ).boldtext( '  Release Date: ' ).boldCyanText(  dateFormat( javaVer.timestamp ) ).boldLine( ' |' )
				.boldLine( repeatString( '-', headerWidth ) )
				.bold( '|' ).boldCyan(  printColumnValue( 'JVM', colWidth ) ).bold( '|' ).boldCyan( printColumnValue( 'OS', colWidth ) ).bold( '|' ).boldCyan( printColumnValue( 'Arch', colWidth ) ).bold( '|' ).boldCyan( printColumnValue( 'Type', lastColWidth ) ).boldLine( '|' )
				.boldLine( repeatString( '-', headerWidth ) );

			javaVer.binaries = javaVer.binaries.sort( function( a, b ) {
				return compareNoCase( a.jvm_impl & a.os & a.architecture & a.image_type, b.jvm_impl & b.os & b.architecture & b.image_type )
			} );
			for( var binary in javaVer.binaries ) {
				print
					.line( '|' & printColumnValue( binary.jvm_impl, colWidth )
						& '|' & printColumnValue( binary.os, colWidth )
						& '|' & printColumnValue( binary.architecture, colWidth )
						& '|' & printColumnValue( binary.image_type, lastColWidth ) & '|' )
					.text( '|' ).yellowText( printColumnValue( 'ID: ' & java.getDefaultNameFromStruct( { version : 'openjdk'&javaVer.version_data.major, type : binary.image_type, arch : binary.architecture, os : binary.os, 'jvm-implementation' : binary.jvm_impl, release : javaVer.release_name } ), headerWidth-2 ) ).line( '|' )
					.line( repeatString( '-', headerWidth ) );
			}
			print.line();
			if( release == 'latest' ) {
				break;
			}
		}
	}


	/**
	* Pads value with spaces or truncates as necessary
	*/
	private function printColumnValue( required string text, required number columnWidth ) {
		if( len( text ) > columnWidth ) {
			text = left( text, columnWidth-3 ) & '...';
		}
		var space = columnWidth-len( text );
		return repeatString( ' ', int( space/2 ) ) & text & repeatString( ' ', columnWidth - text.len() - int( space/2 ) );
	}

	function versionComplete() {

		http
			url="https://api.adoptium.net/v3/info/available_releases"
			throwOnError=false
			timeout=5
			proxyServer="#ConfigService.getSetting( 'proxy.server', '' )#"
			proxyPort="#ConfigService.getSetting( 'proxy.port', 80 )#"
			proxyUser="#ConfigService.getSetting( 'proxy.user', '' )#"
			proxyPassword="#ConfigService.getSetting( 'proxy.password', '' )#"
			result="local.artifactResult";

		var fileContent = toString( local.artifactResult.fileContent );
		if( local.artifactResult.status_code == 200 && isJSON( fileContent ) ) {
			var artifactJSON = deserializeJSON( fileContent );
			return artifactJSON.available_releases;
		}
		return [];
	}

}
