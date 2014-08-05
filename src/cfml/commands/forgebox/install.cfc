/**
 * Download and install an entry from ForgeBox into your application.  You must use the 
 * exact slug for the item you want.  If the item being installed has a box.json descriptor, it's "directory"
 * property will be used as the install location. In the absence of that setting, the current CommandBox working
 * directory will be used.
 * .  
 * Override the installation location by passing the "directory" parameter.  The "save"
 * and "saveDev" parameters will save this package as a dependency or devDependency in your box.json if it exists.
 * .
 * Install the feeds package
 * {code:bash}
 * install feeds
 * {code}
 * .
 * Install feeds and save as a dependency
 * {code:bash}
 * install feeds --save
 * {code}
 * .
 * Install feeds and save as a devDependency
 * {code:bash}
 * install feeds --saveDev
 * {code}
 * .
 * This command can also be called with no slug.  In that instance, it will search for a box.json in the current working
 * directory and install all the dependencies.
 * .
 * Install all dependencies in box.json
 * {code:bash}
 * install
 * {code}
 * .
 * Use the "production" parameter to ignore devDependencies.
 * {code:bash}
 * install --production
 * {code}
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="install" excludeFromHelp=false {
	
	/**
	* The ForgeBox entries cache
	*/
	property name="entries";

	// DI
	property name="forgeBox" 		inject="ForgeBox";
	property name="packageService" 	inject="PackageService";
			
	/**
	* @slug.hint Slug of the ForgeBox entry to install. If no slug is passed, all dependencies in box.json will be installed.
	* @slug.optionsUDF slugComplete
	* @directory.hint The directory to install in. This will override the packages's box.json install dir if provided. 
	* @save.hint Save the installed package as a dependancy in box.json (if it exists)
	* @saveDev.hint Save the installed package as a dev dependancy in box.json (if it exists)
	* @production.hint When calling this command with no slug to install all dependencies, set this to true to ignore devDependencies.
	* @verbose.hint If set, it will produce much more verbose information about the package installation
	**/
	function run( 
		string slug='',
		string directory,
		boolean save=false,
		boolean saveDev=false,
		boolean production=false,
		boolean verbose=false
	){
		
		// Don't default the dir param since we need to differentiate whether the user actually 
		// specifically typed in a param or not since it overrides the package's box.json install dir.
		if( structKeyExists( arguments, 'directory' ) ) {
			
			arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
			
			// Validate directory
			if( !directoryExists( arguments.directory ) ) {
				return error( 'The directory [#arguments.directory#] doesn''t exist.' );
			}
			
		}
				
		arguments.ID = arguments.slug;
		// TODO: climb tree to find root of the site by searching for box.json
		arguments.currentWorkingDirectory = getCWD();
		
		// Install this package.
		// Don't pass directory unless you intend to override the box.json of the package being installed 
		packageService.installPackage( argumentCollection = arguments );
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