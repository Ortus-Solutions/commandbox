/**
 * This command will download and install an entry from ForgeBox into your application.  You must use the 
 *  exact slug for the item you want.  If the item being installed has a box.json descriptor, it's "directory"
 *  property will be used as the install location. In the absence of that setting, the current CommandBox working
 *  directory will be used.  
 *  Override the installation location by passing the "directory" parameter.  The save 
 *  and saveDev parameters will save this package as a dependency or devDependency in your box.json if it exists.
 *  .
 *  # Install the feeds package
 *  forgebox install feeds
 *  .
 *  # Install feeds and save as a dependency
 *  forgebox install feeds --save
 *  .
 *  # Install feeds and save as a devDependency
 *  forgebox install feeds --saveDev
 *  .
 *  This command can also be called with no slug.  In that instance, it will search for a box.json in the current working
 *  directory and install all the dependencies.  Use the --production flag to ignore devDependencies.
 *  .
 *  # Install all dependencies in box.json
 *  forgebox install
 *  .
 *  # Install all dependencies except devDepenencies in box.json
 *  forgebox install --production
 *  
 **/
component extends="commandbox.system.BaseCommand" aliases="install" excludeFromHelp=false {
	
	property name="forgeBox" inject="ForgeBox";
	property name="artifactService" inject="ArtifactService";
	property name="packageService" inject="PackageService";
	property name="tempDir" inject="tempDir";
			
	/**
	* @slug.hint Slug of the ForgeBox entry to install. If no slug is passed, all dependencies in box.json will be installed.
	* @slug.optionsUDF slugComplete
	* @directory.hint The directory to install in. This will override the packages's box.json install dir if provided. 
	* @save.hint Save the installed package as a dependancy in box.json (if it exists)
	* @saveDev.hint Save the installed package as a dev dependancy in box.json (if it exists)
	* @production.hint When calling this command with no slug to install all dependencies, set this to true to ignore devDependencies.
	**/
	function run( 
				string slug,
				string directory,
				boolean save=false,
				boolean saveDev=false,
				boolean production=false ) {
		
		// Don't default the dir param since we need to differentiate whether the user actually 
		// specifically typed in a param or not since it overrides the package's box.json install dir.
		if( structKeyExists( arguments, 'directory' ) ) {
			
			arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
			
			// Validate directory
			if( !directoryExists( arguments.directory ) ) {
				return error( 'The directory [#arguments.directory#] doesn''t exist.' );
			}
			
		}
		
		// If the user gave us a slug, use it
		if( structKeyExists( arguments, 'slug' ) ){
			// TODO, the value should be some default version to install
			var slugs[ arguments.slug ] = '';
		// If there is a box.json...
		} else if( packageService.isPackage( getCWD() ) ) {
			// read it...
			var boxJSON = packageService.readPackageDescriptor( getCWD() );
			// and grab all the dependencies
			var slugs = boxJSON.dependencies;
			// If we're not in production mode...
			if( !arguments.production ) {
				// Add in the devDependencies
				slugs.append( boxJSON.devDependencies );
			}
		// If those fail
		} else {
			// Whine about it
			return error( "You didn't pass a slug and there isn't a box.json here so I'm not sure what to do." );
		}
		
		for( var thisSlug in slugs ) {
			
			try {
				
				print.yellowLine( "Contacting ForgeBox, please wait..." ).toConsole();
	
				// We might have gotten this above
				var entryData = forgebox.getEntry( thisSlug );
				
				// entrylink,createdate,lname,isactive,installinstructions,typename,version,hits,coldboxversion,sourceurl,slug,homeurl,typeslug,
				// downloads,entryid,fname,changelog,updatedate,downloadurl,title,entryrating,summary,username,description,email
								
				if( !val( entryData.isActive ) ) {
					return error( 'The ForgeBox entry [#entryData.title#] is inactive.' );
				}
				
				if( !len( entryData.downloadurl ) ) {
					return error( 'No download URL provided.  Manual install only.' );
				}
	
				// Advice we found it
				print.boldGreenLine( "Found entry: '#thisSlug#'" ).toConsole();
	
				var packageName = thisSlug;
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
				error( '#e.message##CR##e.detail#' );
				continue;
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
			var results = artifactService.installArtifact( argumentCollection = installParams );
			
			print.boldGreenLine( "Installing to: #results.installDirectory#" );		
			
			// Turn this off or put it behind a --verbose flag if it gets annoying
			print.boldGreenLine( "Files Installed" );
			for( var file in results.copied ) {
				print.greenLine( "    #file#" );					
			}				
			print.boldWhiteLine( "Files ignored" );
			for( var file in results.ignored ) {
				print.whiteLine( "    #file#" );					
			}
		
			// Should we save this as a dependancy
			// and is the current working directory a package?
			if( ( arguments.save || arguments.saveDev )  
				&& packageService.isPackage( getCWD() ) ) {
				// Add it!
				packageService.addDependency( getCWD(), installParams.packageName, installParams.version,  arguments.saveDev );
				// Tell the user...
				print.boldGreenLine( "box.json updated with #( arguments.saveDev ? 'dev ': '' )#dependency." );
			}
		
			print.boldGreenLine( "Eureka, '#thisSlug#' has been installed!" );
			
		} // End slug loop
	
		if( slugs.isEmpty() ) {
			print.boldGreenLine( "No dependencies found to install, but it's the thought that counts, right?" );
		}
		
	}

	// Auto-complete list of slugs
	function slugComplete() {
		var result = [];
		// Cache in command
		if( !structKeyExists( variables, 'entries' ) ) {
			variables.entries = forgebox.getEntries();			
		}
		
		// Loop over results and append all active ForgeBox entries
		for( var entry in variables.entries ) {
			if( val( entry.isactive ) ) {
				result.append( entry.slug );
			}
		}
		
		return result;
	}

} 