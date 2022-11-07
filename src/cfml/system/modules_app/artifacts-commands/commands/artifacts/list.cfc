/**
 * List all packages in the CommandBox artifact cache.
 * .
 * {code:bash}
 * artifacts list
 * {code}
 * .
 * Use the "package" parameter to show results for a specific package.
 * {code:bash}
 * artifacts list coldbox-platform
 * {code}
 *
 **/
component {

	// DI
	property name='artifactService' inject='artifactService';

	/**
	 * @package An optional package to filter the results by
	 * @package.optionsUDF packageComplete
	 * @JSON Output data as JSON
	 **/
	function run( package='', boolean JSON=false ) {
		var results = artifactService.listArtifacts( arguments.package );

		if( arguments.JSON ) {
			print.line( results.map( (packageName,packageVersions)=>{
				return packageVersions.reduce( (versions,v)=>{
					versions[ v ] = artifactService.getArtifactPath( packageName, v, false );
					return versions;
				}, {} );
			} ) );
			return;
		}
		if( !results.count() ) {
			print.yellowLine( 'No artifacts found in cache.' );
			return;
		}

		print.boldBlueLine( "Found #results.count()# artifact(s) (#artifactService.getArtifactDir()#)" );

		for( var package in results ) {
			print.boldCyanLine( package & " - #results[ package ].size()# version(s)" );
			for( var ver in results[ package ] ) {
				print.yellowLine( "  *#ver#" );
			}
		}

	}

	function packageComplete() {
		return artifactService.listArtifacts()
			.keyArray();
	}

}
