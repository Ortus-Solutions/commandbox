/**
 * Prune unused artifacts in the CommandBox artifact cache.
 * .
 * {code:bash}
 * artifacts prune
 * {code}
 * .
 * Use the "days" parameter to limit how old artifacts need to be to be pruned.
 * {code:bash}
 * artifacts prune 30
 * {code}
 *
 **/
component {

	// DI
	property name='artifactService' inject='artifactService';

	/**
	 * @days forget artifacts whose last used date is greater or equal to days you set
     * @force skip the "are you sure" confirmation
	 **/
	function run(
        numeric days    = 90,
        boolean force   = false
		) {

		if( arguments.force || confirm( "Really wipe out all artifacts older than #days# old? [y/n]" ) ){
			var results = artifactService.cleanArtifacts( days );
			print.redLine( "Artifacts directory cleaned of '#results#' items." );
		}

	}

}
