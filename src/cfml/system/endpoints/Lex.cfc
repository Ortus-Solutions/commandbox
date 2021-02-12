/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the Lex endpoint.  I get Lucee Extensions from an HTTP URL.
* I will spoof a package around the lex so CommandBox doesn't try to unzip the lex itself.
*/
component accessors=true implements="IEndpoint" singleton {

	// DI
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
		setNamePrefixes( 'lex' );
		return this;
	}

	public string function resolvePackage( required string package, boolean verbose=false ) {
		var job = wirebox.getInstance( 'interactiveJob' );
		var folderName = tempDir & '/' & 'temp#createUUID()#';
		var fullLexPath = folderName & '/' & getDefaultName( package ) & '.lex';
		var fullBoxJSONPath = folderName & '/box.json';
		directoryCreate( folderName );
		var packageLowerCase = lcase( package );

		// Lucee will return TRUE for fileExists( 'http://site.com/package.zip' ) so we have to be explicit here
		if( !( packageLowerCase.startsWith( 'http://' ) || packageLowerCase.startsWith( 'https://' ) || packageLowerCase.startsWith( 's3://' ) ) && fileExists(package)) {
			try{
				job.addLog( "Copying [#package#]" );
				fileCopy(package, folderName);
			} catch (any exName) {
				directoryDelete( folderName, true );
				throw( '#e.message##CR##e.detail#', 'endpointException' );
			}
		} else {
			job.addLog( "Downloading [#package#]" );

			var packageUrl = packageLowerCase.startsWith('s3://') ? S3Service.generateSignedURL(package, verbose) : package;

			try {
				// Download File
				var result = progressableDownloader.download(
					packageUrl, // URL to package
					fullLexPath, // Place to store it locally
					function( status ) {
						progressBar.update( argumentCollection = status );
					},
					function( newURL ) {
						job.addLog( "Redirecting to: '#arguments.newURL#'..." );
					}
				);
			} catch( UserInterruptException var e ) {
				directoryDelete( folderName, true );
				rethrow;
			} catch( Any var e ) {
				directoryDelete( folderName, true );
				throw( '#e.message##CR##e.detail#', 'endpointException' );
			};
		}


		// Spoof a box.json so this looks like a package
		var boxJSON = {
			'name' : '#getDefaultName( package )#.lex',
			'slug' : getDefaultName( package ),
			'version' : '0.0.0',
			'location' : 'lex:#package#',
			'type' : 'lucee-extensions'
		};
		JSONService.writeJSONFile( fullBoxJSONPath, boxJSON );

		// Here is where our alleged so-called "package" lives.
		return folderName;

	}

	public function getDefaultName( required string package ) {

		// Strip protocol and host to reveal just path and query string
		package = package.reReplaceNoCase( '^([\w:]+)?//.*?/', '' );

		// Check and see if the name of the lex appears somewhere in the URL and use that as the package name
		// https://search.maven.org/remotecontent?filepath=jline/jline/3.0.0.M1/jline-3.0.0.M1.lex
		// https://site.com/path/to/package-1.0.0.lex

		// If we see /foo.lex or name=foo.lex or ?foo.lex
		if( package.reFindNoCase( '[/\?=](.*\.lex)' ) ) {
			// Then strip the name and remove extension
			// Note the first .* is greedy so in the case of
			// https://site.com/path/to/file.lex?name=custom.lex
			// the regex will extract the last match, i.e. "custom"
			return package.reReplaceNoCase( '.*[/\?=](.*\.lex).*', '\1' ).left( -4 );
		}

		// We give up, so just make the entire URL a slug
		return reReplaceNoCase( package, '[^a-zA-Z0-9]', '', 'all' );
	}

	public function getUpdate( required string package, required string version, boolean verbose=false ) {
		var result = {
			// lexs with a semver in the name are considered to not have an update since we assume they are an exact version
			isOutdated = !package
				.reReplaceNoCase( '^([\w:]+)?//', '' )
				.listRest( '/\' )
				.reFindNoCase( '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' ),
			version = 'unknown'
		};

		return result;
	}

}
