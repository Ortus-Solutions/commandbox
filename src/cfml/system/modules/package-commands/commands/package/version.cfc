/**
 * Interact with your package's version number.  This command must be run from the root of the package.
 * .
 * Running this command with no parameters will output the current version. (Same as "package show version")
 * .
 * {code:bash}
 * package version
 * {code}
 * .
 * Set a specific version number by passing it into this command.  (Same as "package set version=1.0.0")
 * .
 * {code:bash}
 * package version 1.0.0
 * {code}
 * .
 * "Bump" the existing version number up by one unit and save in your box.json.
 * Specify the part of the version to increase with the major, minor, or patch parameter.  
 * Note, "package version" is aliased as "bump".
 * .
 * {code:bash}
 * bump --major
 * bump --minor
 * bump --patch
 * {code}
 * .
 * If multiple version parts are specified, the "larger" one will be used starting with major.  
 * If a version AND a flag are both supplied, the version will be used and the flag(s) ignored.
 **/
component aliases="bump" {
	
	property name='packageService' inject='PackageService';
	property name='semanticVersion'	inject='semanticVersion';
	property name='parser' inject='Parser';
	
	/**  
	 * @property.hint Name of the property to clear 
	 * @property.optionsUDF completeProperty
	 **/
	function run(
		string version='',
		boolean major,
		boolean minor,
		boolean patch
	) {
		// the CWD is our "package"
		var directory = getCWD();
		
		// Read the box.json.  Missing values will NOT be defaulted.
		var boxJSON = packageService.readPackageDescriptorRaw( directory );
		var versionObject = semanticVersion.parseVersion( semanticVersion.clean( trim( boxJSON.version ?: '' ) ) );
		 
		if( len( arguments.version ) ) {
			
			// Set a specific version
			setVersion( arguments.version );
			
		} else if( structKeyExists( arguments, 'major' ) && arguments.major ) {
			
			// Bump major
			versionObject.major = val( versionObject.major ) + 1;
			versionObject.minor = 0;
			versionObject.revision = 0;
			setVersion( semanticVersion.getVersionAsString( versionObject ) );
			
		} else if( structKeyExists( arguments, 'minor' ) && arguments.minor ) {
			
			// Bump minor
			versionObject.minor = val( versionObject.minor ) + 1;
			versionObject.revision = 0;
			setVersion( semanticVersion.getVersionAsString( versionObject ) );
			
		} else if( structKeyExists( arguments, 'patch' ) && arguments.patch ) {
			
			// Bump patch  
			versionObject.revision = val( versionObject.revision ) + 1;
			setVersion( semanticVersion.getVersionAsString( versionObject ) );
			
		} else {
			
			// Output the version
			runCommand( 'package show version' );
		}						
			
	}

	function setVersion( required string version ) {
		runCommand( 'package set version="' & parser.escapeArg( arguments.version ) & '"' );				
	}
	
}