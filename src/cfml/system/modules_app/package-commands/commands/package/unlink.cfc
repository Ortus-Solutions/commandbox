/**
 * Takes the current module directory and unlinks from another app's modules directory.  The current directory must be a package.
 * Use this command to undo the "package link" command when you're done testing.
 * .
 * The target link must point to the specific modules folder you want to unlink from.
 * The package's slug will be used as the name of the target link to remove.
 * .
 * {code:bash}
 * unlink path/to/app/modules
 * unlink path/to/app/modules_app
 * {code}
 * .
 * If you provide no package path, the module will be unlinked from the local CommandBox core.
 * .
 * {code:bash}
 * unlink
 * {code}
 * .
 * See also: package link
 * 
 **/
component aliases='unlink' {
	property name="packageService" inject="PackageService";

	/**
	 * @moduleDrectory Path to an app's modules directory
	 **/
	function run(
		string moduleDrectory ) {
			
		var packageDirectory=getCWD();
		var commandBoxCoreLinked = false;
		if( !arguments.keyExists( 'moduleDrectory' ) ) {
			arguments.moduleDrectory = expandPath( '/commandbox/modules' );
			commandBoxCoreLinked = true;
		} else {
			arguments.moduleDrectory = fileSystemUtil.resolvePath( arguments.moduleDrectory );
		}
		
		// package check
		if( !packageService.isPackage( packageDirectory ) ) {
			error( '#packageDirectory# is not a package!' );
		}
		
		var boxJSON = packageService.readPackageDescriptor( packageDirectory );
		
		if( !boxJSON.slug.len() ) {
			error( 'Cannot unlink package with no slug.' );
		}
		
		var linkTarget = moduleDrectory & '/' & boxJSON.slug;
		
		if( directoryExists( linkTarget ) ) {
			directoryDelete( linkTarget );
					
			if( commandBoxCoreLinked ) {
				print.greenLine( 'Package [#boxJSON.slug#] unlinked from CommandBox core.' );		
				command( 'reload' )
					.params( clearScreen=false )
					.run();
			} else {
				print.greenLine( 'Package [#boxJSON.slug#] unlinked from [#moduleDrectory#]' );			
			}
			
		} else {
			print.line( 'Looks like the link [#linkTarget#] didn''t exist.  Nothing to see here...' );
		}

	}
}
