/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the HTTP endpoint.  I get packages from an HTTP URL.
*/
component accessors=true implements="IEndpoint" singleton extends="commandbox.system.endpoints.HTTP" {

	// DI
	property name="tempDir" 				inject="tempDir@constants";
	property name="artifactService" 		inject="ArtifactService";
	property name="HTTPEndpoint"			inject="commandbox.system.endpoints.HTTP";
	property name="fileEndpoint"			inject="commandbox.system.endpoints.File";
	property name='wirebox'					inject='wirebox';

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'HTTP+cached' );
		return this;
	}

	public string function resolvePackage( required string package, string currentWorkingDirectory="", boolean verbose=false ) {
		var job = wirebox.getInstance( 'interactiveJob' );
		var artifactName = getDefaultName( package );


		if( !artifactService.artifactExists( 'HTTP_Cached', artifactName ) ) {

			// Store in artifacts for next time
			artifactService.createArtifact(
				'HTTP_Cached',
				artifactName,
				// Defer to HTTP endpoint
				HTTPEndpoint.resolvePackageZip( package, arguments.verbose )
			);

		} else {
			job.addLog( "Lucky you, we found this version in local artifacts!" );
		}

		// By now it will exist in artifacts
		return fileEndpoint.resolvePackage(
			artifactService.getArtifactPath( 'HTTP_Cached', artifactName )
		);

	}

}
