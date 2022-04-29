/**
 * Takes the current module directory and link it to another app's modules directory.  The current directory must be a package.
 * This is useful for live testing of a module that's under development without needing to install and update the installation
 * with every change.  You're operating system's local symlink capabilities will be used.  This requires a file system that
 * supports symlinks.
 * .
 * The target link must not be just to the root of the app, but the specific modules folder you want to link into.
 * The package's slug will be used as the name of the target link.
 * .
 * {code:bash}
 * link path/to/app/modules
 * link path/to/app/modules_app
 * {code}
 * .
 * If you provide no package path, the module will be linked into the local CommandBox core.
 * .
 * {code:bash}
 * link
 * {code}
 * .
 * If there already exists a module or linked package in the target location, use --force but bear in mind
 * This will delete the existing folder or link first.
 * .
 * {code:bash}
 * link --force
 * {code}
 *
 * Linking a package is not the same as installing it.  The target box.json will not be modified nor will any dependencies be installed.
 * You'll need to run an "install" in the local module you're developing to install its dependencies, which will in turn be part of the link.
 * .
 * See also: package unlink
 *
 **/
component aliases='link' {
	property name="packageService" inject="PackageService";
	property name="moduleService" inject="moduleService";

	/**
	 * @moduleDirectory Path to an app's modules directory
	 * @force Overwrite any existing module or link.
	 **/
	function run(
		string moduleDirectory,
		boolean force=false ) {

		var packageDirectory=getCWD();
		var commandBoxCoreLinked = false;
		if( !arguments.keyExists( 'moduleDirectory' ) ) {
			arguments.moduleDirectory = expandPath( '/commandbox/modules' );
			commandBoxCoreLinked = true;
			if( !directoryExists( arguments.moduleDirectory ) ) {
				directoryCreate( arguments.moduleDirectory );
			}
		} else {
			arguments.moduleDirectory = resolvePath( arguments.moduleDirectory );
			if( !directoryExists( arguments.moduleDirectory ) ) {
				error( 'The target directory [#arguments.moduleDirectory#] doesn''t exist.' );
			}
		}

		// package check
		if( !packageService.isPackage( packageDirectory ) ) {
			error( '#packageDirectory# is not a package!' );
		}


		var boxJSON = packageService.readPackageDescriptor( packageDirectory );

		if( !boxJSON.slug.len() ) {
			error( 'Cannot link package with no slug.' );
		}
		if( !packageService.isPackageModule( boxJSON.type ) ) {
			error( 'Package type [#boxJSON.type#] is invalid for linking.  Needs to be a module type.' );
		}

		var linkTarget = moduleDirectory & '/' & boxJSON.slug;
		// Check to see if link or module already exists
		if( directoryExists( linkTarget ) ) {
			if( force ) {
				print
					.yellowLine( 'Deleting old folder/link...' )
					.toConsole();

				directoryDelete( linkTarget );
				// Sometimes I get errors that I think are due to the actual delete happening async by my disk subsystem.
				// Let's give it a second to complete.
				sleep( 1000 );
			} else {
				error( 'Target folder [#linkTarget#] already exists.  Use --force to override.' );
			}
		}

		var oFiles = createObject( 'java', 'java.nio.file.Files' );
		var oFileTarget = fileSystemUtil.getJavaFile( linkTarget );
		var oFileSource = fileSystemUtil.getJavaFile( packageDirectory );

		try {
			oFiles.createSymbolicLink( oFileTarget.toPath(), oFileSource.toPath(), [] );
		} catch( any var e ) {
			error( 'Could not link package. Try running your shell as administrator', e.message );
		}

		if( commandBoxCoreLinked ) {
			print.greenLine( 'Package [#boxJSON.slug#] linked to CommandBox core.  Activating!' );
			loadModule( linkTarget );
		} else {
			print.greenLine( 'Package [#boxJSON.slug#] linked to [#moduleDirectory#]' );
		}
	}
	
	
	function loadModule( required string moduleDirectory ) {
		moduleDirectory = resolvePath( moduleDirectory );

		// Generate a CF mapping that points to the module's folder
		var relativeModulePath = fileSystemUtil.makePathRelative( moduleDirectory );

		// A dot delimited path that points to the folder containing the module
		var invocationPath = relativeModulePath
			.listChangeDelims( '.', '/\' )
			.listDeleteAt( relativeModulePath.listLen( '/\' ), '.' );

		// The name of the module
		var moduleName = relativeModulePath.listLast( '/\' );

		// Load it up!!
		moduleService.registerAndActivateModule( moduleName, invocationPath );
	}
	
}
