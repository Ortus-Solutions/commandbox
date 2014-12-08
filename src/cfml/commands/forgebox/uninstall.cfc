/**
 * Uninstall a package from your application.  The installation path is pulled from box.json based on package name.
 * If the package being uninstalled has a box.json, any dependencies and devDependencies 
 * will also be uninstalled as well.
 * .
 * If a directory is supplied, the package will be looked for in that directory.  Otherwise, the box.json for the packge will be 
 * inspected for an install path for that package.  Lasty, the command will look in the current directory for a folder named after the package.
 * .
 * Uninstall the feeds package
 * {code:bash}
 * forgebox uninstall feeds
 * {code}
 * .
 * Uninstall feeds but don't remove it from the dependency list
 * {code:bash}
 * forgebox install feeds --!save
 * {code}
 * .
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
	* @directory.hint The directory the package is currently installed in including the container folder
	* @save.hint Remove package as a dependancy in box.json (if it exists)
	* @saveDev.hint Remove package as a dev dependancy in box.json (if it exists)
	**/
	function run( 
		required string slug='',
		string directory,
		boolean save=true
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