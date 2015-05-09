/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the HTTP endpoint.  I get packages from an HTTP URL.
*/
component accessors="true" implements="IEndpoint" singleton {
		
	// DI
	property name="consoleLogger"			inject="logbox:logger:console";
	property name="tempDir" 				inject="tempDir@constants";
	property name="artifactService" 		inject="ArtifactService";
	property name="fileEndpoint"			inject="endpoints.file";
	property name="progressableDownloader" 	inject="ProgressableDownloader";
	property name="progressBar" 			inject="ProgressBar";
	
	// Properties
	property name="namePrefixes" type="string";
	
	function init() {
		setNamePrefixes( 'HTTP' );
		return this;
	}
		
	public string function resolvePackage( required string package, boolean verbose=false ) {
		
		// TODO: Add artifacts caching
		
		var fileName = 'temp#randRange( 1, 1000 )#.zip';
		var fullPath = tempDir & '/' & fileName;		
		
		// Download File
		var result = progressableDownloader.download(
			getNamePrefixes() & ':' & package, // URL to package
			fullPath, // Place to store it locally
			function( status ) {
				progressBar.update( argumentCollection = status );
			},
			function( newURL ) {
				consoleLogger.info( "Redirecting to: '#arguments.newURL#'..." );
			}
		);
		
		// Defer to file endpoint
		return fileEndpoint.resolvePackage( fullPath, arguments.verbose );
		
	}

}