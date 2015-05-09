/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the file endpoint.  I get packages from a local file.
*/
component accessors="true" implements="IEndpoint" singleton {
		
	// DI
	property name="consoleLogger"		inject="logbox:logger:console";
	property name="tempDir" 			inject="tempDir@constants";
	property name="artifactService" 	inject="ArtifactService";
	property name="packageService" 	inject="packageService";
	property name="fileSystemUtil"		inject="FileSystem";
	
	// Properties
	property name="namePrefixes" type="string";
	
	function init() {
		setNamePrefixes( 'file' );
		return this;
	}
		
	public string function resolvePackage( required string package, boolean verbose=false ) {
	
	
		// Has file size?
		if( getFileInfo( package ).size <= 0 ) {
			throw( 'Cannot install file as it has a file size of 0.', 'endpointException', package );
		}
		
		// Normalize slashes
		var packagePath = fileSystemUtil.resolvePath( "#variables.tempDir#/#createUUID()#" );
		
		// Unzip to temp directory
		consoleLogger.info( "Uncompressing...");
		
		zip action="unzip" file="#package#" destination="#packagePath#" overwrite="true";
		
		packagePath = packageService.findPackageRoot( packagePath );
		
		return packagePath;

	}

}