/**
 * Removes generated Java build output so the next build starts fresh.
 *
 * {code:bash}
 * java clean
 * java clean --dependencies
 * {code}
 *
 * The main and test class output trees are removed, along with the JAR output for
 * the current version in the libs directory. Dependency directories are left alone
 * unless --dependencies is passed, so a clean does not force a re-download.
 *
 * `java compile --clean` and `java test --clean` run this step first and then
 * continue, which is the equivalent of `gradle clean build` versus `gradle build`.
 **/
component extends="commandbox.system.BaseCommand" {

	property name="packageService"  inject="PackageService";
	property name="fileSystemUtil"  inject="FileSystem";

	/**
	 * @projectRootDirectory Project directory used as the path-resolution root
	 * @dependencies Also remove the runtime and dev dependency directories
	 * @JSON Return the clean result without the text output
	 */
	function run(
		string projectRootDirectory="",
		boolean dependencies=false,
		boolean JSON=false
	) {
		var dsl = compile( arguments.projectRootDirectory );
		var removed = dsl.clean().removed;

		if( arguments.dependencies ) {
			removed.append( removeDependencyDirectories( dsl.getProjectRoot() ), true );
		}

		var result = { "projectRoot" : dsl.getProjectRoot(), "removed" : removed };

		if( arguments.JSON ) {
			print.line( result );
			return;
		}

		if( !removed.len() ) {
			print.line( "Nothing to clean. Run `java compile` to build the project." ).toConsole();
			return;
		}

		for( var removedPath in removed ) {
			print.cyanLine( "- Removed: #replaceNoCase( removedPath, dsl.getProjectRoot(), "" )#" ).toConsole();
		}
		print.greenLine( "Java build output cleaned." ).toConsole();
	}

	/**
	 * Removes the runtime and dev dependency directories from box.json's maven block.
	 *
	 * When a directory is not configured the convention default is used, so a
	 * project that never installed anything simply has nothing to remove.
	 *
	 * @projectRoot The project root to read box.json from.
	 * @returns The absolute paths that were removed.
	 */
	private array function removeDependencyDirectories( required string projectRoot ) {
		var mavenConfig = {};
		if( packageService.isPackage( arguments.projectRoot ) ) {
			mavenConfig = packageService.readPackageDescriptorRaw( arguments.projectRoot ).maven ?: {};
		}

		var removed = [];
		var dependencyDirectories = [
			mavenConfig.installDirectory    ?: "dist/dependencies",
			mavenConfig.devInstallDirectory ?: "dist/test-dependencies"
		];

		for( var dependencyDirectory in dependencyDirectories ) {
			if( !isSimpleValue( dependencyDirectory ) || !len( trim( dependencyDirectory ) ) ) {
				continue;
			}
			var resolvedDirectory = fileSystemUtil.resolvePath( trim( dependencyDirectory ), arguments.projectRoot );
			if( !directoryExists( resolvedDirectory ) ) {
				continue;
			}
			directoryDelete( resolvedDirectory, true );
			removed.append( resolvedDirectory );
		}

		return removed;
	}

}
