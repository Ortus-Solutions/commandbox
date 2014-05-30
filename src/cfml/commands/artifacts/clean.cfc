/**
 * Clean out the artifacts cache.  Removes all stored packages.
 *
 * artifacts clean
 *
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	property name='artifactService' inject='artifactService';

	function run(  ) {
		var results = artifactService.cleanArtifacts();
		
		print.line( results );
	}

}