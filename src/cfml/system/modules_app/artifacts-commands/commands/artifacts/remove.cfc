/**
 * Remove 1 or more packages from the artifacts cache by package name.
 * Use this command to force the "install" command to re-download the files fresh.
 * .
 * Remove all versions of the package
 * {code:bash}
 * artifacts remove package-name
 * {code}
 * .
 * Remove a specific version of the package
 * {code:bash}
 * artifacts remove package-name 1.2.0.0
 * {code}
 * .
 * Remove a list of packge names
 * {code:bash}
 * artifacts remove package1,package2
 * {code}
 * .
 * Skip the prompt with the "force" parameter
 * {code:bash}
 * artifacts remove package-name --force
 * {code}
 *
 **/
component {

	// DI
	property name='artifactService' inject='artifactService';

	/**
	 * @package Comma-delimited list of packages to remove
	 * @package.optionsUDF packageComplete
	 * @version If passed, it will try to remove a specific package version
	 * @version.optionsUDF versionComplete
	 * @force Do not confirm, just delete
	 **/
	function run( required string package, version="", boolean force=false ) {
		// convert to array incoming package
		arguments.package = listToArray( arguments.package );
		// doc version string
		var versionString = version.len() ? ":#arguments.version#" : "";

		// iterate and remove
		for( var thisPackage in arguments.package ){

			// verify if package exists
			if( !artifactService.packageExists( thisPackage, arguments.version ) ){
				print.redLine( "Package: #thisPackage# does not exist!" ).
					redLine( "Try 'artifacts list' to see what packages are in the cache." );
				continue;
			}
			// Confirm removal
			if( arguments.force eq false && !confirm( "Really remove: #thisPackage##versionString#? [y/n]" ) ){
				continue;
			}
			// Remove Package
			artifactService.removeArtifact( thisPackage, arguments.version );
			print.greenLine( "Package: #thisPackage##versionString# removed!" );
		}

	}
	
	function packageComplete() {
		return artifactService.listArtifacts()
			.keyArray();
	}
	
	function versionComplete() {
		var results = artifactService.listArtifacts( arguments.passedNamedParameters.package ?: '' );
		
		if( results.count() ) {
			return results[ results.keyArray().first() ];
		}
			
		return [];
	}

}
