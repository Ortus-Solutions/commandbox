/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle Java installs for servers to use
*
*/
component accessors="true" singleton {

	// DI
	property name='packageService' 		inject='packageService';
	property name='configService' 		inject='configService';
	property name='interceptorService' 	inject='InterceptorService';
	property name='fileSystemUtil' 		inject='fileSystem';

	property name='javaDirectory';

	/**
	* DI complete
	*/
	function onDIComplete() {
		interceptorService.registerInterceptor( this );

		variables.lastInstallDir = '';

		variables.javaInstallDirectory = expandPath( '/commandbox-home/serverJREs' );

		// Create the java directory if it doesn't exist
		if( !directoryExists( getJavaInstallDirectory() ) ) {
			directoryCreate( getJavaInstallDirectory() );
			// Init it as a package
			packageService.writePackageDescriptor( {
				'name' : 'CommandBox Java Installation Registry',
				'version' : '1.0.0',
				'slug' : 'commandbox-java-installation-registry',
				'type' : 'projects'
			}, getJavaInstallDirectory() );
		}

	}

	/**
	* List the Java installations including the Java install CommandBox is running
	*/
	struct function listJavaInstalls() {
		return packageService.buildDependencyHierarchy( getJavaInstallDirectory(), 1 ).dependencies;
	}

	/**
	* Remove a Java install
	*
	* @ID Full ID of java installation
	*/
	function uninstallJava( required string ID ) {
		packageService.uninstallPackage(
			ID=ID,
			save=true,
			currentWorkingDirectory=getJavaInstallDirectory()
		);
	}

	/**
	* Detect whether a specific version is installed
	*
	* @ID Full ID of java installation
	*/
	boolean function javaInstallExists( required string ID ){
		return structkeyExists( listJavaInstalls(), ID );
	}

	/**
	* Install java version if needed, and return installation folder
	*
	* @ID Full ID of java installation
	* @verbose Enable verbose output from the install command
	*/
	function getJavaInstallPath( required string ID, boolean verbose=false ){
		installJava( ID, verbose );
		return lastInstallDir;
	}

	/**
	* Install a java version
	*
	* @ID installation ID as defined by Java endpoint.  If no endpoint name space, defaults to "java:"
	* @verbose Enable verbose output from the install command
	*/
	function installJava( required string ID, boolean verbose=false ) {
		// Default to "java:" endpoint
		if( ID.listLen( ':' ) == 1 ) {
			ID = 'java:' & ID;
		}
		// If java endpoint, lock in version
		if( ID.left( 5 ) == 'java:' ) {
			ID &= ':lockVersion';
		}

		// Install it!
		packageService.installPackage(
			ID=ID,
			save=true,
			currentWorkingDirectory=getJavaInstallDirectory(),
			verbose=verbose
		);
	}

	/**
	* Returns the full path to where server java installs are stored
	*/
	string function getJavaInstallDirectory() {
		return configService.getSetting( 'server.javaInstallDirectory', variables.javaInstallDirectory );
	}


	/**
	* Sort of hacky way to capture the last place we installed Java into
	*/
	function postInstall() {
		if( fileSystemUtil.normalizeSlashes( interceptData.installDirectory ) contains fileSystemUtil.normalizeSlashes( getJavaInstallDirectory() ) ) {
			lastInstallDir = interceptData.installDirectory;
		}
	}

}
