/**
 * Search for avaialble versions of java for you to use
 * .
 * {code:bash}
 * server java search
 * {code}
 *
 * version is required for the API to work so you can only search for builds of the same major version at a time.
 * .
 * {code:bash}
 * server java search version=openjdk8
 * server java search version=openjdk9
 * server java search version=openjdk10
 * server java search version=openjdk11
 * {code}
 *
 * version, jvm, arch, os, and type are defaulted automatically based on your local PC.
 * You can search across all options by passing in blank for each param
 * .
 * {code:bash}
 * server java search jvm= arch= type= os=
 * {code}
 *
 **/
component aliases='java search' {

	// DI
	property name="javaService"		inject="JavaService";
	property name="packageService"	inject="PackageService";
	property name="java"			inject="commandbox.system.endpoints.java";

	/**
	* @version Major OpenJDK version such as "openjdk8"
	* @version.options openjdk8,openjdk9,openjdk10,openjdk11,openjdk12,openjdk13
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
	*/
	function run(
		version = 'openjdk11',
		jvm = 'hotspot',
		os,
		arch = server.java.archModel contains 32 ? 'x32' : 'x64',
		type = 'jre',
		release = 'latest'
	){
		
		if( isNull( os) ) {
			if( fileSystemUtil.isMac() ) {
				os = 'mac';
			} else if( fileSystemUtil.isLinux() ) {
				os = 'linux';
			} else {
				os = 'windows';
			}
		}
		
		var APIURLCheck = 'https://api.adoptopenjdk.net/v2/info/releases/#version.lcase()#?';
		
		if( jvm.len() ) {
			APIURLCheck &= '&openjdk_impl=#encodeForURL( jvm )#';
		}
		if( os.len() ) {
			APIURLCheck &= '&os=#encodeForURL( os )#';
		}
		if( arch.len() ) {
			APIURLCheck &= '&arch=#encodeForURL( arch )#';
		}
		if( type.len() ) {
			APIURLCheck &= '&type=#encodeForURL( type )#';
		}
		if( release.len() ) {
			APIURLCheck &= '&release=#encodeForURL( release )#';
		}
		
		print
			.line()
			.line( 'Hitting API URL:' )
			.indentedline( APIURLCheck )
			.line()
			.line();
			
		http
			url="#APIURLCheck#"
			throwOnError=false
			proxyServer="#ConfigService.getSetting( 'proxy.server', '' )#"
			proxyPort="#ConfigService.getSetting( 'proxy.port', 80 )#"
			proxyUser="#ConfigService.getSetting( 'proxy.user', '' )#"
			proxyPassword="#ConfigService.getSetting( 'proxy.password', '' )#"
			result="local.artifactResult";
	
		if( local.artifactResult.status_code == 200 && isJSON( local.artifactResult.fileContent ) ) {
			var artifactJSON = deserializeJSON( local.artifactResult.fileContent );
			
			// Sometimes the API gives me back a struct, sometimes I get an array of structs. ¯\_(ツ)_/¯
			if( isStruct( artifactJSON ) ) {
				artifactJSON = [ artifactJSON ];
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
					return compareNoCase( a.openjdk_impl & a.os & a.architecture & a.binary_type, b.openjdk_impl & b.os & b.architecture & b.binary_type )
				} );
				for( var binary in javaVer.binaries ) {
					print
						.line( '|' & printColumnValue( binary.openjdk_impl, colWidth ) 
							& '|' & printColumnValue( binary.os, colWidth )
							& '|' & printColumnValue( binary.architecture, colWidth )
							& '|' & printColumnValue( binary.binary_type, lastColWidth ) & '|' )
						.text( '|' ).yellowText( printColumnValue( 'ID: ' & java.getDefaultNameFromStruct( { version : version, type : binary.binary_type, arch : binary.architecture, os : binary.os, 'jvm-implementation' : binary.openjdk_impl, release : javaVer.release_name } ), headerWidth-2 ) ).line( '|' )
						.line( repeatString( '-', headerWidth ) );
				}
				print.line();
			}
		} else {
			print.boldRedLine( 'There was an error hitting the API.  [#local.artifactResult.status_code#]' );
			print.redLine( local.artifactResult.fileContent.left( 100 ) );
		}	
	}


	/**
	* Pads value with spaces or truncates as neccessary
	*/
	private function printColumnValue( required string text, required number columnWidth ) {
		if( len( text ) > columnWidth ) {
			text = left( text, columnWidth-3 ) & '...';
		}
		var space = columnWidth-len( text );
		return repeatString( ' ', int( space/2 ) ) & text & repeatString( ' ', columnWidth - text.len() - int( space/2 ) );
	}

}