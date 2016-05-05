/**
 * Interact with your package's version number.  This command must be run from the root of the package.
 * .
 * Running this command with no parameters will output the current version. (Same as "package show version")
 * .
 * {code:bash}
 * package version
 * {code}
 * .
 * Set a specific version number by passing it into this command.  (Same as "package set version=1.0.0")
 * .
 * {code:bash}
 * package version 1.0.0
 * {code}
 * .
 * "Bump" the existing version number up by one unit and save in your box.json.
 * Specify the part of the version to increase with the major, minor, or patch parameter.  
 * Note, "package version" is aliased as "bump".
 * .
 * {code:bash}
 * bump --major
 * bump --minor
 * bump --patch
 * {code}
 * .
 * If multiple version parts are specified, the "larger" one will be used starting with major.  
 * If a version AND a flag are both supplied, the version will be used and the flag(s) ignored.
 **/
component aliases="bump" {
	
	property name='packageService' inject='PackageService';
	property name='configService' inject='ConfigService';
	property name='semanticVersion'	inject='semanticVersion';
	property name='interceptorService'	inject='interceptorService';
	
	/**  
	 * @version The new version to set into this package
	 * @message The message to use when commiting the new tag
	 * @tagVersion Whether or not to tag the repo
	 * @force Skip the check if to see if the Git repo is clean
	 * @major Increment the major version number
	 * @minor Increment the minor version number
	 * @patch Increment the patch version number
	 **/
	function run(
		string version='',
		string message,
		boolean tagVersion,
		boolean force = false,
		boolean major,
		boolean minor,
		boolean patch
	) {
		// the CWD is our "package"
		arguments.directory = getCWD();
		
		// Read the box.json.  Missing values will NOT be defaulted.
		var boxJSON = packageService.readPackageDescriptorRaw( arguments.directory );
		var versionObject = semanticVersion.parseVersion( trim( boxJSON.version ?: '' ) );
		 
		if( len( arguments.version ) ) {
			
			// Set a specific version
			arguments.version = semanticVersion.clean( arguments.version );
			setVersion( argumentCollection=arguments );
			
		} else if( structKeyExists( arguments, 'major' ) && arguments.major ) {
			
			// Bump major
			versionObject.major = val( versionObject.major ) + 1;
			versionObject.minor = 0;
			versionObject.revision = 0;
			arguments.version =  semanticVersion.getVersionAsString( versionObject );
			setVersion( argumentCollection=arguments );
			
		} else if( structKeyExists( arguments, 'minor' ) && arguments.minor ) {
			
			// Bump minor
			versionObject.minor = val( versionObject.minor ) + 1;
			versionObject.revision = 0;
			arguments.version =  semanticVersion.getVersionAsString( versionObject );
			setVersion( argumentCollection=arguments );
			
		} else if( structKeyExists( arguments, 'patch' ) && arguments.patch ) {
			
			// Bump patch  
			versionObject.revision = val( versionObject.revision ) + 1;
			arguments.version =  semanticVersion.getVersionAsString( versionObject );
			setVersion( argumentCollection=arguments );
			
		} else {
			
			// Output the version
			return command( 'package show version' )
				.run( returnOutput=true );
		}						
			
	}

	function setVersion( required string version, boolean tagVersion, string message, string directory, required boolean force ) {

		interceptorService.announceInterception( 'preVersion', { versionArgs=arguments } );

		command( 'package set'  )
			.params( version=arguments.version )
			.run();
			
		// If this package is also a Git repository
		var repoPath = '#arguments.directory#/.git';
		arguments.tagVersion = arguments.tagVersion ?: ConfigService.getSetting( 'tagVersion', true );
		if( directoryExists( repoPath ) && arguments.tagVersion ) {
			print.yellowLine( 'Package is a Git repo.  Tagging...' );

			try {
				
				// The main Git API
				var GitAPI = createObject( 'java', 'org.eclipse.jgit.api.Git' );
				
				var git = GitAPI.open( createObject( 'java', 'java.io.File' ).init( repoPath ) );
				var diffs = git.diff()
					.setCached( true )
					.setShowNameAndStatusOnly( true )
					.call();
				
				// Make sure there aren't staged file ready to commit (clean working dir)
				if( arrayLen( diffs ) && !arguments.force ) {
					print.line()
						.boldRedLine( 'The working directory is not clean.' );
					for( var entryDiff in diffs ) {
						print.yellowLine( entryDiff.getChangeType() & ' ' & entryDiff.getNewPath() );
					}
					error( 'Cannot tag Git repo. Please commit file, or use --force flag to skip this check' );
				}
						
				arguments.message = arguments.message ?: ConfigService.getSetting( 'tagVersionMessage', '${version}' );
				arguments.message = replaceNoCase( arguments.message, '${version}', arguments.version, 'all' );
				
				// Add the box.json
				git.add()
					.addFilepattern( 'box.json' )
					.call();
				
				// Commit the box.json
				git.commit()
					.setMessage( arguments.message ) 
					.call();
				
				// Tag this version
				git.tag()
					.setName( 'v#arguments.version#' )
					.setMessage( arguments.message )
					.call();
			
				print.yellowLine( 'Tag [v#arguments.version#] created.' ).toConsole();
			} catch( any var e ) {
				logger.error( 'Error tagging Git repository with new version.', e );
				error( 'Error tagging Git repository with new version.', e.message & ' ' & e.detail );
			}
		
		}

		interceptorService.announceInterception( 'postVersion', { versionArgs=arguments } );				
						
	}
	
}
