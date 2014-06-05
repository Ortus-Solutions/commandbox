/**
 * Remove 1 or more packages from the artifacts cache. This will remove
 * all versions for a specified package
 * 
 * artifacts remove package-name
 * artifacts remove package1,package2
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	// DI
	property name='artifactService' inject='artifactService'; 

	/**
	 * @packages.hint comma-delimited list of packages to remove
	 * @force.hint Do not confirm, just delete
	 **/
	function run( required string package, boolean force=false ) {
		// convert to array incoming package
		arguments.package = listToArray( arguments.package );

		// iterate and remove
		for( var thisPackage in arguments.package ){

			// verify if package exists
			if( !artifactService.packageExists( thisPackage ) ){
				print.redLine( "Package: #thisPackage# does not exist!" ).
					redLine( "Try 'artifacts list' to see what packages are in the cache." );
				continue;
			}
			// Confirm removal
			if( arguments.force eq false && !confirm( "Really remove: #thisPackage#? [y/n]" ) ){
				continue;
			}
			// Remove Package
			artifactService.removeArtifact( thisPackage );
			print.greenLine( "Package: #thisPackage# removed!" );
		}

	}

}