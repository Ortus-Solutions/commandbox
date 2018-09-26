/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the Jar endpoint.  I get bare jar files from an HTTP URL.
* I will spoof a package around the jar so CommandBox doesn't try to unzip the jar itself.
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
	property name='S3Service'				inject='S3Service';

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'jar' );
		return this;
	}

	public string function resolvePackage( required string package, boolean verbose=false ) {
		var job = wirebox.getInstance( 'interactiveJob' );
		var folderName = tempDir & '/' & 'temp#randRange( 1, 1000 )#';
		directoryCreate( folderName );
		var fullJarPath = folderName & '/' & getDefaultName( package ) & '.jar';
		var fullBoxJSONPath = folderName & '/box.json';

		job.addLog( "Downloading [#package#]" );

		var packageUrl = package.startsWith('s3://') ? S3Service.generateSignedURL(package, verbose) : package;

		try {
			// Download File
			var result = progressableDownloader.download(
				packageUrl, // URL to package
				fullJarPath, // Place to store it locally
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

		// Spoof a box.json so this looks like a package
		var boxJSON = {
			'name' : '#getDefaultName( package )#.jar',
			'slug' : getDefaultName( package ),
			'version' : '0.0.0',
			'location' : 'jar:#package#',
			'type' : 'jars'
		};
		JSONService.writeJSONFile( fullBoxJSONPath, boxJSON );

		// Here is where our alleged so-called "package" lives.
		return folderName;

	}

	public function getDefaultName( required string package ) {

		var baseURL = arguments.package;

		// strip query string, unless it possibly contains .jar like so:
		// https://search.maven.org/remotecontent?filepath=jline/jline/3.0.0.M1/jline-3.0.0.M1.jar
		if( !right( arguments.package, 4 ) == '.jar' ) {
			baseURL = listFirst( arguments.package, '?' );
		}

		// Find last segment of URL (may or may not be a file)
		var fileName = listLast( baseURL, '/' );

		// Check for file extension in URL
		var fileNameListLen = listLen( fileName, '.' );
		if( fileNameListLen > 1 && listLast( fileName, '.' ) == 'jar' ) {
			return listDeleteAt( fileName, fileNameListLen, '.' );
		}
		// We give up, so just make the entire URL a slug
		return reReplaceNoCase( baseURL, '[^a-zA-Z0-9]', '', 'all' );
	}

	public function getUpdate( required string package, required string version, boolean verbose=false ) {
		var result = {
			// Jars with a semver in the name are considered to not have an update since we assume they are an exact version
			isOutdated = !package
				.reReplaceNoCase( 'http(s)?://', '' )
				.listRest( '/\' )
				.reFindNoCase( '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' ),
			version = 'unknown'
		};

		return result;
	}

}
