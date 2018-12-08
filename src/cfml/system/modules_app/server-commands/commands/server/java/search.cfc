/**
 * Search for avaialble versions of java for you to use
 * .
 * {code:bash}
 * server java search
 * {code}
 **/
component aliases='java search' {

	// DI
	property name="javaService" inject="JavaService";
	property name="packageService" inject="PackageService";

	/**
	* @version Major OpenJDK version such as "openjdk8"
	* @version.options openjdk8,openjdk9,openjdk10,openjdk11
	* @jvm The JVM Implementation such as "hotspot" or "openj9"
	* @jvm.options hotspot,openj9
	* @os The operating system. Windows, linux, or mac
	* @os.options windows,linux,mac
	* @arch CPU Architecture such as x64 or x32
	* @arch.options x64, x32, ppc64, s390x, ppc64le, aarch64
	* @type Whether the build is a JRE or JDK.
	* @type.options jdk,jre
	*/
	function run(
		version = 'openjdk11',
		jvm = 'hotspot',
		os,
		arch = server.java.archModel contains 32 ? 'x32' : 'x64',
		type = 'jre'
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
			APIURLCheck &= '&openjdk_impl=#jvm#' 
		}
		if( os.len() ) {
			APIURLCheck &= '&os=#os#' 
		}
		if( arch.len() ) {
			APIURLCheck &= '&arch=#arch#' 
		}
		if( type.len() ) {
			APIURLCheck &= '&type=#type#' 
		}
	
		print.line( APIURLCheck ).line().line();
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
			for( var javaVer in artifactJSON ) {
				
				print.boldCyanText( javaVer.release_name ).line( '  ' & javaVer.timestamp );
				for( var binary in javaVer.binaries ) {
					print
						.indentedLine( binary.os & ' ' & binary.architecture & ' ' & binary.binary_type  & ' ' & binary.openjdk_impl );
				}
				print.line();
			}
		} else {
			print.boldRedLine( 'There was an error hitting the API.  [#local.artifactResult.status_code#]' );
			print.redLine( local.artifactResult.fileContent.left( 100 ) );
		}	
	}


}