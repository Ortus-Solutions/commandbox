/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the CFLIb endpoint.  I get packages from CFblib.org based on their slug.
* install cflib:UDFName
*/
component accessors="true" implements="IEndpoint" singleton {
		
	// DI
	property name="consoleLogger"			inject="logbox:logger:console";
	property name="tempDir" 				inject="tempDir@constants";
	property name="progressableDownloader" 	inject="ProgressableDownloader";
	property name="progressBar" 			inject="ProgressBar";
	
	// Properties
	property name="namePrefixes" type="string";
	
	function init() {
		setNamePrefixes( 'CFLib' );
		return this;
	}
		
	public string function resolvePackage( required string package, boolean verbose=false ) {
		
		var folderName = tempDir & '/' & 'temp#randRange( 1, 1000 )#';
		var fullPath = folderName & '/' & package & '.cfm';
		
		directoryCreate( folderName, true, true );
		
		// Download File
		var result = progressableDownloader.download(
			'http://www.cflib.org/udfdownload/' & package,
			fullPath,
			function( status ) {
				progressBar.update( argumentCollection = status );
			},
			function( newURL ) {
				consoleLogger.info( "Redirecting to: '#arguments.newURL#'..." );
			}
		);
		
		fixTags( fullPath );
		
		return folderName;
		
	}

	public function getDefaultName( required string package ) {
		return reReplaceNoCase( arguments.package, '[^a-zA-Z0-9]', '', 'all' );
	}

	public function getUpdate( required string package, required string version, boolean verbose=false ) {
		var result = {
			isOutdated = true,
			version = 'unknown'
		};
		
		return result;
	}

	// If this is a scrpt-based function, wrap it in cfscript so it at least complies
	private function fixTags( required string fileName ) {
		// Read the file we just downloaded
		var fileContents = fileRead( arguments.fileName );
		// If it doesn't contain a tag-based function
		if( !findNoCase( '<c' & 'ffunction', fileContents ) ) {
			// wrap it in cfscript
			fileContents = '<c' & 'fscript>#chr(13)##chr(10)#' & fileContents & '#chr(13)##chr(10)#</c' & 'fscript>';
			fileWrite( arguments.fileName, fileContents ); 
		}
	}

}