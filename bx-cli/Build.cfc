component {
	property name='packageService'			inject='packageService';

	function run() {
		var boxJSON = packageService.readPackageDescriptor( resolvePath( "" ) );
		var moduleSrcPath = resolvePath( "src/system" )
		var repoSrcPath = resolvePath( "../src/cfml/system" );
		if( directoryExists( moduleSrcPath ) ) {
			directoryDelete( moduleSrcPath, true );
		}
		directoryCreate( moduleSrcPath );
		directoryCopy( repoSrcPath, moduleSrcPath, true );
		command( "tokenReplace" ).params( moduleSrcPath & "Shell.cfc", "@build.version@", boxJSON.version, true ).run();

		// TODO: get libs

		// TODO: get bx modules

		command( "forgebox use" ).params( "ortus" ).run();
		command( "publish" ).flags( "force" ).run();
	}
}