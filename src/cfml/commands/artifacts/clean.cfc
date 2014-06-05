/**
 * Clean out the artifacts cache.  Removes all stored packages.
 *
 * artifacts clean
 *
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	// DI
	property name='artifactService' inject='artifactService';

	function run() {
		if( confirm( "Really wipe out the entire artifacts cache? [y/n]" ) ){
			var results = artifactService.cleanArtifacts();
			print.redLine( "Artifacts directory cleaned of '#results#' items." );
		}
	}

}