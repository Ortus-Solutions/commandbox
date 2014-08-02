/**
 * This command will uninstall a package from your application.  The directory we look for the package in is follows the same
 * pattern that the install command uses.  If the package being uninstalled has a box.json, any dependencies and devDependencies 
 * will also be uninstalled as well.
 * .
 * If a directory is supplied, the package will be looked for in that directory in a 
 * subfolder named after the slug.  Otherwise, the box.json for the packge will be read (which may require connecting to the 
 * online registry if it isn't found in the local artifacts cache) and its directory property will be used.  If no box.json
 * can be found for the package, this command will look in the current working directory.
 * .
 * The "save" and "saveDev" parameters will remove this package as a dependency or devDependency in your root box.json if it exists.
 * .
 * # Uninstall the feeds package
 * forgebox uninstall feeds
 * .
 * # Uninstall feeds and remove it from the dependency list
 * forgebox install feeds --save
 * .
 * # Uninstall feeds and remove it from the dev dependency list
 * forgebox install feeds --saveDev
 *
 **/
component extends="commandbox.system.BaseCommand" aliases="uninstall" excludeFromHelp=false {
	
	/**
	* The ForgeBox entries cache
	*/
	property name="entries";

	// DI
	property name="forgeBox" 		inject="ForgeBox";
	property name="packageService" 	inject="PackageService";
			
	/**
	* @slug.hint Slug of the package to uninstall. 
	* @slug.optionsUDF slugComplete
	* @directory.hint The directory the package is currenlty installed in. Defaults to current dir or the packages's box.json install dir if provided.  
	* @save.hint Remove package as a dependancy in box.json (if it exists)
	* @saveDev.hint Remove package as a dev dependancy in box.json (if it exists)
	**/
	function run( 
		required string slug='',
		string directory,
		boolean save=false,
		boolean saveDev=false
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
		
		// Uninstall this package.
		// Don't pass directory unless you intend to override the box.json of the package being uninstalled 
		packageService.uninstallPackage( argumentCollection = arguments );
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