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
	property name="tempDir"				inject="tempDir@constants";
	property name="packageService"		inject="packageService";
	property name="fileSystemUtil"		inject="FileSystem";
	property name="folderEndpoint"		inject="commandbox.system.endpoints.Folder";
	property name="semanticVersion"		inject="provider:semanticVersion@semver";

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
		consoleLogger.info( "Decompressing...");

		zip action="unzip" file="#package#" destination="#packagePath#" overwrite="true";

		// Defer to folder endpoint
		return folderEndpoint.resolvePackage( packagePath, arguments.verbose );

	}

	/**
	* Determines the name of a package based on its ID if there is no box.json
	*/
	public function getDefaultName( required string package ) {
		var fileName = listLast( arguments.package, '/\' );
		return listFirst( fileName, '.' );
	}

	public function getUpdate( required string package, required string version, boolean verbose=false ) {
		var result = {
			isOutdated = true,
			version = 'unknown'
		};

		if( fileExists( arguments.package ) ) {

			var boxJSONPath = 'zip://' & arguments.package & '!box.json';

			// If the packge has a box.json in the root...
			if( fileExists( boxJSONPath ) ) {

				// ...Read it.
				var boxJSON = fileRead( boxJSONPath );

				// Validate the file is valid JSOn
				if( isJSON( boxJSON ) ) {
					// Merge this JSON with defaults
					boxJSON = packageService.newPackageDescriptor( deserializeJSON( boxJSON ) );
					result.isOutdated = semanticVersion.isNew( current=arguments.version, target=boxJSON.version );
					result.version = boxJSON.version;
				} // isJSON
			} // box.json exists
		} // zip exists

		return result;
	}

}
