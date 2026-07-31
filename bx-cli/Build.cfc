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
		command( "tokenReplace" ).params( moduleSrcPath & "Bootstrap.cfm", "@build.version@", boxJSON.version, true ).run();

		// Get bx modules
		// TODO: remove need for evaluate, compat, etc
		var bxModuleSlugs = "bx-compat-cfml,bx-esapi,bx-unsafe-evaluate,bx-wddx";
		// wipe out modules folder
		var modulesPath = resolvePath( "modules" );
		if( directoryExists( modulesPath ) ) {
			directoryDelete( modulesPath, true );
		}
		// now install!
		command( "install" ).params( bxModuleSlugs, modulesPath ).flags( "!save", "force" ).run();

		// Get libs (specified in box.json)
		// clear libs folder
		var libsPath = resolvePath( "libs" );
		if( directoryExists( libsPath ) ) {
			directoryDelete( libsPath, true );
		}
		directoryCreate( libsPath );
		command( "install" ).run();

		compile()
			.fromSource( "../src/java/com" )
			.toClasses( "../temp/cli/jgit-classes" )
			.withClassPath( [ "libs" ] )
			.toJar( "ortus-jgit.jar" )
			.run();

		command( "forgebox use" ).params( "ortus" ).run();
		command( "publish" ).flags( "force" ).run();
	}

}