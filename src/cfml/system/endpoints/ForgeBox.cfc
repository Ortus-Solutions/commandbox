/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the ForgeBox endpoint.  I wrap CFML's coolest package repository
*/
component accessors="true" implements="IEndpointInteractive" singleton {
		
	// DI
	property name="CR" 					inject="CR@constants";
	property name="consoleLogger"		inject="logbox:logger:console";
	property name="forgeBox" 			inject="ForgeBox";
	property name="tempDir" 			inject="tempDir@constants";
	property name="semanticVersion"		inject="semanticVersion";
	property name="artifactService" 	inject="ArtifactService";
	property name="packageService" 		inject="packageService";
	property name="fileSystemUtil"		inject="FileSystem";
	property name="fileEndpoint"		inject="commandbox.system.endpoints.File";
	
	// Properties
	property name="namePrefixes" type="string";
	
	function init() {
		setNamePrefixes( 'forgebox' );
		return this;
	}
		
	public string function resolvePackage( required string package, boolean verbose=false ) {
		var entryData = {};
		var slug = parseSlug( arguments.package );
		var version = parseVersion( arguments.package );
				
		// If we have a specific version and it exists in artifacts, use it.  Otherwise, to ForgeBox!!
		if( semanticVersion.isExactVersion( version ) && artifactService.artifactExists( slug, version ) ) {
			consoleLogger.info( "Package found in local artifacts!");
		} else {
			entryData = getPackage( slug, version, arguments.verbose );
			version = entryData.version;
		}
		
		// Assert: at this point, the package is downloaded and exists in the local artifact cache
	
		// Install the package
		var thisArtifactPath = artifactService.getArtifactPath( slug, version );
	
		// Defer to file endpoint
		packagePath = fileEndpoint.resolvePackage( thisArtifactPath, arguments.verbose );
		
		// Cheat for people who set a version, slug, or type in ForgeBox, but didn't put it in their box.json
		// We can only do this if we talked to ForgeBox, but I'm trying hard not to use network IO if I can get the package from artifacts.
		if( structCount( entryData ) ) {
			var boxJSON = packageService.readPackageDescriptorRaw( packagePath );
			if( !structKeyExists( boxJSON, 'type' ) || !len( boxJSON.type ) ) { boxJSON.type = entryData.typeslug; }
			if( !structKeyExists( boxJSON, 'slug' ) || !len( boxJSON.slug ) ) { boxJSON.slug = entryData.slug; }
			if( !structKeyExists( boxJSON, 'version' ) || !len( boxJSON.version ) ) { boxJSON.version = entryData.version; }
			packageService.writePackageDescriptor( boxJSON, packagePath );
		}
		return packagePath;

	}
	
	public function getDefaultName( required string package ) {
		// if "foobar@2.0" just return "foobar"
		return listFirst( arguments.package, '@' );
	}

	public function getUpdate( required string package, required string version, boolean verbose=false ) {
		var slug = parseSlug( arguments.package );
		var version = parseVersion( arguments.package );
		var result = {
			isOutdated = false,
			version = ''
		};
		
		// Verify in ForgeBox
		var fbData = forgebox.getEntry( slug );
		// Verify if we are outdated, internally isNew() parses the incoming strings
		result.isOutdated = semanticVersion.isNew( current=version, target=fbData.version );
		result.version = fbData.version;
		
		return result;		
	}


	public function createUser(
		required string username,
		required string password,
		required string email,
		required string firstName,
		required string lastName ) {
		throw( 'Not implemented' );
	}
	
	public string function login( required string userName,required string password ) {
		throw( 'Not implemented' );
	}
	
	public function publish( required string path ) {
		throw( 'Not implemented' );
	}	

	
	// Private methods

	private function getPackage( slug, version, verbose=false ) {		
	
		try {
			// Info
			consoleLogger.warn( "Verifying package '#slug#' in ForgeBox, please wait..." );
			
			// TODO: Check ForgeBox for highest version that satisfies what was requested.
			
			var entryData = forgebox.getEntry( slug );
			// Verbose info
			if( arguments.verbose ){
				consoleLogger.debug( "Package data retrieved: ", entryData );
			}
			
			// entrylink,createdate,lname,isactive,installinstructions,typename,version,hits,coldboxversion,sourceurl,slug,homeurl,typeslug,
			// downloads,entryid,fname,changelog,updatedate,downloadurl,title,entryrating,summary,username,description,email
							
			if( !val( entryData.isActive ) ) {				
				throw( 'The ForgeBox entry [#entryData.title#] is inactive.', 'endpointException' );
			}
			
			if( !len( entryData.downloadurl ) ) {
				throw( 'No download URL provided in ForgeBox.  Manual install only.', 'endpointException' );
			}
	
			var packageType = entryData.typeSlug;
			version = entryData.version;
			
			// Advice we found it
			consoleLogger.info( "Verified entry in ForgeBox: '#slug#'" );
	
			arguments.version = entryData.version;
			
			// If the local artifact doesn't exist, download and create it
			if( !artifactService.artifactExists( slug, version ) ) {
					
				consoleLogger.info( "Starting download of: '#slug#'..." );
				
				// Store the package locally in the temp dir
				var packageTempPath = forgebox.install( slug, tempDir );
				
				// Store it locally in the artfact cache
				artifactService.createArtifact( slug, version, packageTempPath );
				
				// Clean up the temp file
				fileDelete( packageTempPath );
								
				consoleLogger.info( "Done." );
				
			} else {
				consoleLogger.info( "Package found in local artifacts!");
			}
			
			
		} catch( forgebox var e ) {
			// This can include "expected" errors such as "slug not found"
			throw( '#e.message##CR##e.detail#', 'endpointException' );
		}
		
		return entryData;
		
	}
		
	private function parseSlug( required string package ) {
		return listFirst( arguments.package, '@' );
	}
		
	private function parseVersion( required string package ) {
		var version = '';
		// foo@1.0.0
		if( arguments.package contains '@' ) {
			// Note this can also be a semvar range like 1.2.x, >2.0.0, or 1.0.4-2.x
			// For now I'm assuming it's a specific version
			version = listRest( arguments.package, '@' );
		}
		return version;
	}
	
}