/**
 * This command will download and install an entry from ForgeBox into your application.  You must use the 
 *  exact slug for the item you want.  If the item being installed has a box.json descriptor, it's "directory"
 *  property will be used as the install location. In the absence of that setting, the current CommandBox working
 *  directory will be used.  Override the installation location by passing the "directory" parameter.
 *  
 *  forgebox install feeds
 *  
 **/
component extends="commandbox.system.BaseCommand" aliases="install" excludeFromHelp=false {
	
	property name="forgeBox" inject="ForgeBox";
	property name="artifactService" inject="ArtifactService";
	property name="tempDir" inject="tempDir";
			
	/**
	* @slug.hint Slug of the ForgeBox entry to install
	* @directory.hint The directory to install in. This will override the packages's box.json install dir if provided.
	**/
	function run( 
				required slug,
				directory ) {
		
		// Don't default the dir param since we need to differentiate whether the user actually 
		// specifically typed in a param or not since it overrides the package's box.json install dir.
		if( structKeyExists( arguments, 'directory' ) ) {
			
			arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
			
			// Validate directory
			if( !directoryExists( arguments.directory ) ) {
				return error( 'The directory [#arguments.directory#] doesn''t exist.' );
			}
			
		}
		
		try {
			
			print.yellowLine( "Contacting ForgeBox, please wait..." ).toConsole();

			// We might have gotten this above
			var entryData = forgebox.getEntry( slug );
			
			// entrylink,createdate,lname,isactive,installinstructions,typename,version,hits,coldboxversion,sourceurl,slug,homeurl,typeslug,
			// downloads,entryid,fname,changelog,updatedate,downloadurl,title,entryrating,summary,username,description,email
							
			if( !val( entryData.isActive ) ) {
				return error( 'The ForgeBox entry [#entryData.title#] is inactive.' );
			}
			
			if( !len( entryData.downloadurl ) ) {
				return error( 'No download URL provided.  Manual install only.' );
			}

			// Advice we found it
			print.boldGreenLine( "Found entry: '#arguments.slug#'" ).toConsole();

			var packageName = arguments.slug;
			var version = entryData.version;
			
			// If the local artifact doesn't exist, download and create it
			if( !artifactService.artifactExists( packageName, version ) ) {
					
				print.boldGreenLine( "Starting download from: '#entryData.downloadURL#'..." ).toConsole();
					
				// Grab from the project's download URL and store locally in the temp dir
				var packageTempPath = forgebox.install( entryData.downloadurl, tempDir );
				
				// Store it locally in the artfact cache
				artifactService.createArtifact( packageName, version, packageTempPath );
				
				// Clean up the temp file
				fileDelete( packageTempPath );
								
				print.boldGreenLine( "Done." );	
				
			}
			
			
		} catch( forgebox var e ) {
			// This can include "expected" errors such as "slug not found"
			return error( '#e.message##CR##e.detail#' );
		}
			
		print.boldGreenLine( "Installing from local artifact cache..." ).toConsole();

		// Assert: at this point, the package is downloaded and exists in the local artifact cache

		var installParams = {
			packageName : packageName,
			version : version
		};

		// If the user didn't specify this, don't pass it since it overrides the package's desired isntall location
		if( structKeyExists( arguments, 'directory' ) ) {
			installParams.installDirectory = arguments.directory;
		}
		
		// Install the package
		artifactService.installArtifact( argumentCollection = installParams );
	
		print.boldGreenLine( "Eureka, '#arguments.slug#' has been installed!" );
		
		
	}

} 