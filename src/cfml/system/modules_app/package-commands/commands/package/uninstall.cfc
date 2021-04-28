/**
 * Uninstall a package from your application.  The installation path is pulled from box.json based on package name.
 * If the package being uninstalled has a box.json, any dependencies and devDependencies
 * will also be uninstalled as well.
 * .
 * If a directory is supplied, the package will be looked for in that directory.  Otherwise, the box.json for the package will be
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
	property name="packageService" 	inject="PackageService";

	/**
	* @slug.hint Slug of the package to uninstall.
	* @slug.optionsUDF slugComplete
	* @directory.hint The directory the package is currently installed in including the container folder
	* @save.hint Remove package as a dependency in box.json (if it exists)
	* @system.hint Uninstall this package from the global CommandBox module's folder
	* @verbose.hint Output verbose uninstallation information
	**/
	function run(
		required string slug='',
		string directory,
		boolean save=true,
		boolean system=false,
		boolean verbose=false
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

		// account for system slugs
		var systemPackageSlugs = returnPackageSlugs();
		var localPackageSlugs = returnPackageSlugs( getCWD() );
		// exists as system package and not as local package
		var isSystemPackageOnly = systemPackageSlugs.containsnocase( arguments.slug ) && !localPackageSlugs.containsnocase( arguments.slug );

		if( arguments.system || isSystemPackageOnly ) {
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
			var directoryPackages = returnPackageSlugs( directory ).map(
				function( item, index ){
					return { 'name' = item, 'group' = 'Packages' };
				}
			);
			results.append( directoryPackages, true );
		}

		// account for system slugs
		var systemPackages = returnPackageSlugs().map(
			function( item, index ){
				return { 'name' = item, 'group' = 'Packages (--system)' };
			}
		);
		results.append( systemPackages, true );

		return results;
	}

	/**
	* If no directory is provided, it defaults to the system directory to be the system directory
	*/
	private array function returnPackageSlugs( string directory = expandPath( '/commandbox' ) ) {
		var BoxJSON = packageService.readPackageDescriptor( arguments.directory );
		return BoxJSON.installPaths.keyArray();
	}

}
