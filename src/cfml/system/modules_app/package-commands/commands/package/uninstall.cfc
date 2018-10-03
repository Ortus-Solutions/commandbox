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
component aliases="uninstall" {

	// DI
	property name="forgeBox" 		inject="ForgeBox";
	property name="packageService" 	inject="PackageService";

	/**
	* @slug.hint Slug of the package to uninstall.
	* @slug.optionsUDF slugComplete
	* @directory.hint The directory the package is currently installed in including the container folder
	* @save.hint Remove package as a dependancy in box.json (if it exists)
	* @system.hint When true, uninstall this package from the global CommandBox module's folder
	**/
	function run(
		required string slug='',
		string directory,
		boolean save=true,
		boolean system=false
	){

		// Don't default the dir param since we need to differentiate whether the user actually
		// specifically typed in a param or not since it overrides the package's box.json install dir.
		if( structKeyExists( arguments, 'directory' ) ) {

			arguments.directory = resolvePath( arguments.directory );

			// Validate directory
			if( !directoryExists( arguments.directory ) ) {
				return error( 'The directory [#arguments.directory#] doesn''t exist.' );
			}

		}

		if( arguments.system ) {
			arguments.currentWorkingDirectory = expandPath( '/commandbox' );
		} else {
			arguments.currentWorkingDirectory = getCWD();
		}

		// Convert slug to array
		arguments.slug = listToArray( arguments.slug );
		// iterate and uninstall.
		for( var thisSlug in arguments.slug ){
			arguments.ID = thisSlug;
			// Uninstall this package.
			// Don't pass directory unless you intend to override the box.json of the package being uninstalled
			packageService.uninstallPackage( argumentCollection = arguments );
		}
	}

	// Auto-complete list of slugs
	function slugComplete() {
		var results = [];
		var directory = getCWD();

		if( packageService.isPackage( directory ) ) {
			var BoxJSON = packageService.readPackageDescriptor( directory );
			results.append( BoxJSON.installPaths.keyArray(), true );
		}

		return results;
	}

}
