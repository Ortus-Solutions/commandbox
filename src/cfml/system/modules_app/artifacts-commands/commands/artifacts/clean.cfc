/**
 * Remove all packages from the artifacts cache.  Cached packages will be removed from the file system.
 * Use this command to force the "install" command to re-download the files fresh.
 * .
 * {code:bash}
 * artifacts clean
 * {code}
 * .
 * Use the "force" parameter to skip the prompt.
 * .
 * {code:bash}
 * artifacts clean --force
 * {code}
 *
 **/
component {

	// DI
	property name='artifactService' inject='artifactService';

	/**
	 * @force.hint Set to true to skip the prompt
	 *
	 **/
	function run( boolean force=false ) {

		if( arguments.force || confirm( "Really wipe out the entire artifacts cache? [y/n]" ) ){
			var results = artifactService.cleanArtifacts();
			print.redLine( "Artifacts directory cleaned of '#results#' items." );
		}

	}

}