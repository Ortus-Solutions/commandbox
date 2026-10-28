/**
 * Tests for the `git:` endpoints (`git`, `git+https`, `git+http`, `git+ssh`, `github`).
 *
 * Every assertion covering an install is taken from a documented behavior on the Git endpoint
 * docs page (https://commandbox.ortusbooks.com/package-management/code-endpoints/git) — the doc
 * is the spec, not the implementation.
 *
 * Run from this directory with:
 *
 *     box task run taskFile=Task.cfc
 *
 * Pass `verbose=true` to see the endpoints' own logging:
 *
 *     box task run taskFile=Task.cfc :verbose=true
 *
 * All generated output goes under `scratch/` (gitignored); nothing tracked in the repo is
 * modified.  Network access is required.  The `git+ssh` tests additionally require a working
 * ~/.ssh identity that the Git server accepts.
 *
 * The "Apache MINA sshd migration guards" section is a regression guard.  JGit's SSH support was
 * moved off JSch because JSch (last released 2018) cannot read the OpenSSH private key format and
 * cannot negotiate ed25519 / rsa-sha2-*, which is why modern keys and hosts failed to
 * authenticate.
 *
 * Intentionally NOT covered here: authenticated clones against third-party private repos (no
 * credentials available), the ~/.netrc code path (would require writing to the user's home
 * directory), proxy configuration, and submodule cloning.
 */
component {

	/**
	 * Discovers and runs every `@test`-annotated function in this CFC.
	 */
	function run( boolean verbose=false ) {
		variables.failures = [];
		variables.verbose = arguments.verbose;
		var testFunctions = this.$bx.meta.functions.filter( function( functionMetadata ) {
			return functionMetadata.annotations.keyExists( "test" );
		} );

		testFunctions.each( function( functionMetadata ) {
			print.line().yellowLine( "── Running #functionMetadata.name# ──" ).toConsole();
			try {
				invoke( this, functionMetadata.name, { "verbose" : variables.verbose } );
				print.greenLine( "✓ #functionMetadata.name# passed" ).toConsole();
			} catch( any e ) {
				variables.failures.append( {
					"name"    : functionMetadata.name,
					"message" : e.message,
					"detail"  : e.detail ?: ""
				} );
				print.redLine( "✗ #functionMetadata.name# failed" ).redLine( "  #e.message#" ).toConsole();
			}
		} );

		print.line().toConsole();
		print.line( "Git endpoint tests: #testFunctions.len() - variables.failures.len()# passed, #variables.failures.len()# failed." ).toConsole();
		variables.failures.each( function( failure ) {
			print.redLine( "✗ #failure.name#: #failure.message#" ).toConsole();
		} );

		if( variables.failures.len() ) {
			error( "#variables.failures.len()# Git endpoint test(s) failed." );
		}
	}

	// ==============================================================================================
	// Installation — documented URL formats
	// ==============================================================================================

	/**
	 * Doc: `install git+https://github.com/username/repoName.git`
	 *
	 * @test
	 */
	function gitHTTPSInstall( boolean verbose=false ) {
		var target = scratchDirectory( "git-https" );
		install( "git+https://github.com/octocat/Hello-World.git", target, arguments.verbose );

		assertPackageInstalled( target, "Hello-World" );
	}

	/**
	 * Doc: `install git://github.com/username/repoName.git`
	 *
	 * @test
	 */
	function gitProtocolInstall( boolean verbose=false ) {
		var target = scratchDirectory( "git-protocol" );
		install( "git://github.com/octocat/Hello-World.git", target, arguments.verbose );

		assertPackageInstalled( target, "Hello-World" );
	}

	/**
	 * Doc: "If the repo you wish to install is located on Github.com, you can use this shortcut
	 * to specifying the package" — `install username/repoName`.
	 *
	 * @test
	 */
	function githubShortcutResolvesToGitHubEndpoint( boolean verbose=false ) {
		var resolved = getInstance( "endpointService" ).resolveEndpointData( "octocat/Hello-World", getCWD() );
		assertEquals( "github", resolved.endpointName, "the user/repo shortcut must resolve to the github endpoint" );
		assertEquals( "octocat/Hello-World", resolved.package, "the shortcut must be passed through as the package" );

		var target = scratchDirectory( "github-shortcut" );
		install( "octocat/Hello-World", target, arguments.verbose );
		assertPackageInstalled( target, "Hello-World" );
	}

	// ==============================================================================================
	// Commit-ish support
	// ==============================================================================================

	/**
	 * Doc: "You can target a specific `branch`, `tag`, or `commit` by adding a commit-ish to the
	 * end of the URL" — `install git://site.com/user/repo.git#development`
	 *
	 * @test
	 */
	function commitIshBranch( boolean verbose=false ) {
		var target = scratchDirectory( "commit-ish-branch" );
		install( "git+https://github.com/Ortus-Solutions/commandbox-cfconfig.git##master", target, arguments.verbose );

		assertPackageInstalled( target, "commandbox-cfconfig" );
	}

	/**
	 * Doc: commit-ish may be a tag — `install git://site.com/user/repo.git#v1.2.3`
	 *
	 * @test
	 */
	function commitIshTag( boolean verbose=false ) {
		var target = scratchDirectory( "commit-ish-tag" );
		install( "git+https://github.com/Ortus-Solutions/commandbox-cfconfig.git##v2.3.0", target, arguments.verbose );

		assertPackageInstalled( target, "commandbox-cfconfig" );
	}

	/**
	 * Doc: commit-ish may be a commit hash — `#09d302b4fffa0b988d1edd8ea747dc0c0f2883ea`
	 *
	 * @test
	 */
	function commitIshCommitHash( boolean verbose=false ) {
		var target = scratchDirectory( "commit-ish-sha" );
		install( "git+https://github.com/Ortus-Solutions/commandbox-cfconfig.git##a5059d4", target, arguments.verbose );

		assertPackageInstalled( target, "commandbox-cfconfig" );
	}

	/**
	 * Doc: "If you don't specify a commit-ish, the Git endpoint will assume you want the `master`
	 * branch.  If there is no `master` branch, we will attempt to checkout the `main` branch."
	 *
	 * @test
	 */
	function defaultsToMasterBranch( boolean verbose=false ) {
		var target = scratchDirectory( "default-branch" );
		install( "git+https://github.com/Ortus-Solutions/commandbox-cfconfig.git", target, arguments.verbose );

		assertPackageInstalled( target, "commandbox-cfconfig" );
	}

	// ==============================================================================================
	// Package metadata
	// ==============================================================================================

	/**
	 * Doc: "Make sure the root of your Git repo has a `box.json` inside of it so CommandBox can
	 * tell the version and name of the package."
	 *
	 * @test
	 */
	function boxJsonFromRepoIsUsed( boolean verbose=false ) {
		var target = scratchDirectory( "boxjson-from-repo" );
		install( "git+https://github.com/Ortus-Solutions/commandbox-cfconfig.git", target, arguments.verbose );

		var boxJSON = deserializeJSON( fileRead( target & "/commandbox-cfconfig/box.json" ) );
		assertEquals( "commandbox-cfconfig", boxJSON.slug, "the slug must come from the repo's box.json" );
		assertEquals( "commandbox-modules", boxJSON.type, "the type must come from the repo's box.json" );
	}

	/**
	 * Doc: "If there is no `box.json`, the name of the repo will be used as the package name."
	 *
	 * @test
	 */
	function packageNameFallsBackToRepoName( boolean verbose=false ) {
		var endpoint = getInstance( "endpointService" ).getEndpoint( "git" );

		assertEquals( "Hello-World", endpoint.getDefaultName( "git+https://github.com/octocat/Hello-World.git" ), "the .git suffix must be dropped" );
		assertEquals( "MyRepo", endpoint.getDefaultName( "git+https://github.com/octocat/MyRepo.git" ), "the repo name is used verbatim for a .git URL" );
		// The documented "use the repo name" fallback only yields a clean name when the URL ends in
		// .git; otherwise the whole identifier is reduced to its alphanumerics.
		assertEquals( "githttpsgithubcomoctocatMyRepo", endpoint.getDefaultName( "git+https://github.com/octocat/MyRepo" ), "non-.git URLs are reduced to alphanumerics" );
		assertEquals( "MyRepo", endpoint.getDefaultName( "git+https://github.com/octocat/MyRepo.git##v1.2.3" ), "the commit-ish must be ignored" );
	}

	/**
	 * Doc: dependencies may be declared in `box.json` as a git URL for the package.
	 *
	 * @test
	 */
	function dependencyDeclaredInBoxJson( boolean verbose=false ) {
		var target = scratchDirectory( "boxjson-dependency" );
		fileWrite(
			target & "/box.json",
			serializeJSON( {
				"name"         : "git-dependency-test",
				"version"      : "1.0.0",
				"dependencies" : {
					"Hello-World" : "git+https://github.com/octocat/Hello-World.git"
				}
			}, true )
		);

		var installCommand = command( "install" ).inWorkingDirectory( target );
		if( arguments.verbose ) {
			installCommand.flags( "verbose" );
		}
		installCommand.run();

		assertPackageInstalled( target, "Hello-World" );
	}

	// ==============================================================================================
	// SSH
	// ==============================================================================================

	/**
	 * Doc: "CommandBox's Git endpoint supports SSH authentication via public/private keys by using
	 * the `git+ssh://` protocol", and private repos need a user before the host:
	 * `install git+ssh://git@github.com:user/repo.git`
	 *
	 * @test
	 */
	function gitSSHPublicInstall( boolean verbose=false ) {
		var target = scratchDirectory( "git-ssh" );
		install( "git+ssh://git@github.com:octocat/Hello-World.git", target, arguments.verbose );

		assertPackageInstalled( target, "Hello-World" );
	}

	// ==============================================================================================
	// Error reporting
	// ==============================================================================================

	/**
	 * A missing HTTPS repo must fail loudly and include the underlying JGit reason.
	 *
	 * This also guards the exception-cause walking that replaced the old `CommandCaller` Java
	 * helper: if the nested cause is dropped again, the message degrades to a bare "not authorized"
	 * with no transport context.
	 *
	 * @test
	 */
	function missingHTTPSRepoFailsWithUsefulMessage( boolean verbose=false ) {
		var target = scratchDirectory( "error-https" );
		var message = assertThrows( () => resolvePackage( "git+https://github.com/octocat/this-repo-does-not-exist-xyz.git", target ) );

		assertTrue(
			message.findNoCase( "not authorized" ) || message.findNoCase( "TransportException" ),
			"expected the underlying JGit transport reason to be surfaced, got [#message#]"
		);
	}

	/**
	 * A missing SSH repo must surface the server's own message.  This proves the MINA session
	 * factory actually connected and received an answer, rather than failing to set up SSH at all.
	 *
	 * @test
	 */
	function missingSSHRepoFailsWithUsefulMessage( boolean verbose=false ) {
		var target = scratchDirectory( "error-ssh" );
		var message = assertThrows( () => resolvePackage( "git+ssh://git@github.com:octocat/no-such-repo-xyz.git", target ) );

		assertTrue(
			message.findNoCase( "Repository not found" ) || message.findNoCase( "NoRemoteRepositoryException" ),
			"expected the server's message to be surfaced, got [#message#]"
		);
	}

	// ==============================================================================================
	// Apache MINA sshd migration guards
	// ==============================================================================================

	/**
	 * The transport callback must attach Apache MINA's session factory.  If this ever reports a
	 * JSch factory, the migration has been reverted.
	 *
	 * @test
	 */
	function sshTransportGetsMinaSessionFactory( boolean verbose=false ) {
		var transport = sshTransportFor( "git@github.com:octocat/Hello-World.git" );

		assertTrue( isNull( transport.getSshSessionFactory() ), "a fresh SSH transport must not already have a session factory" );

		new commandbox.system.util.JGitSSHCallback().configure( transport );

		var factory = transport.getSshSessionFactory();
		assertTrue( !isNull( factory ), "the callback must attach a session factory" );
		assertTrue(
			isInstanceOf( factory, "org.eclipse.jgit.transport.SshSessionFactory" ),
			"the attached factory must be an SshSessionFactory, got [#factory.getClass().getName()#]"
		);
		// JGit builds the factory from its builder, so assert on the package rather than the exact class.
		// A JSch implementation would be org.eclipse.jgit.transport.ssh.jsch.* instead.
		assertTrue(
			factory.getClass().getName().startsWith( "org.eclipse.jgit.transport.sshd." ),
			"the attached factory must come from JGit's Apache MINA package, got [#factory.getClass().getName()#]"
		);
	}

	/**
	 * Doc: "The `git+ssh` endpoint will look for a private SSH key in your `~/.ssh` directory named
	 * `id_rsa`, `id_dsa`, or `identity`."
	 *
	 * MINA's own default list stops after `id_ed25519` and does not include `identity`, so the
	 * endpoint supplies its own resolver.  This locks in the documented filenames.
	 *
	 * @test
	 */
	function sshIdentityFilesIncludeDocumentedNames( boolean verbose=false ) {
		var sshDirectory = scratchDirectory( "ssh-identities" );
		fileWrite( sshDirectory & "/id_rsa", "placeholder" );
		fileWrite( sshDirectory & "/id_dsa", "placeholder" );
		fileWrite( sshDirectory & "/identity", "placeholder" );
		fileWrite( sshDirectory & "/id_ed25519", "placeholder" );
		// A file that is not a key must never be offered
		fileWrite( sshDirectory & "/config", "placeholder" );

		var names = new commandbox.system.util.JGitSSHCallback()
			.getDefaultIdentities( createObject( "java", "java.io.File" ).init( sshDirectory ) )
			.map( ( path ) => path.getFileName().toString() );

		[ "id_rsa", "id_dsa", "identity", "id_ed25519" ].each( ( expected ) => {
			assertTrue( names.find( expected ) > 0, "expected [#expected#] to be offered as an identity, got [#names.toList()#]" );
		} );
		assertTrue( names.find( "config" ) == 0, "non-key files must not be offered as identities" );
		assertTrue( names.find( "not-there" ) == 0, "files that do not exist must not be offered" );
	}

	/**
	 * MINA verifies server keys by default.  The endpoint must keep trusting unknown hosts, because
	 * the previous JSch factory forced `StrictHostKeyChecking=no` and users rely on cloning from
	 * hosts that are not in their `known_hosts`.
	 *
	 * @test
	 */
	function sshAcceptsUnknownHostKeys( boolean verbose=false ) {
		var keyDatabase = new commandbox.system.util.JGitAcceptAllServerKeyDatabase();

		assertEquals( 0, keyDatabase.lookup( "example.com", "", "" ).len(), "no keys are persisted, so lookup returns nothing" );
		assertEquals( true, keyDatabase.accept( "example.com", "", "", "", "" ), "unknown host keys must be accepted" );
	}

	/**
	 * The reason for the migration: JSch 0.1.55 could not negotiate modern algorithms, which is why
	 * servers rejected RSA/SHA-1 keys.  Assert the replacements are on the runtime classpath and
	 * that the JSch stack is gone.
	 *
	 * @test
	 */
	function modernSSHAlgorithmsAreAvailable( boolean verbose=false ) {
		var signatures = createObject( "java", "org.apache.sshd.common.signature.BuiltinSignatures" );

		assertEquals( "rsa-sha2-256", signatures.rsaSHA256.getName(), "RSA/SHA-256 signature" );
		assertEquals( "rsa-sha2-512", signatures.rsaSHA512.getName(), "RSA/SHA-512 signature" );
		assertEquals( "ssh-ed25519", signatures.ed25519.getName(), "Ed25519 signature" );

		assertClassAbsent( "com.jcraft.jsch.JSch", "JSch must no longer be on the classpath" );
		assertClassAbsent( "org.eclipse.jgit.transport.ssh.jsch.JschConfigSessionFactory", "JGit's JSch transport must no longer be on the classpath" );
		assertClassPresent( "org.eclipse.jgit.transport.sshd.SshdSessionFactory", "JGit's MINA transport must be present" );
	}

	// ==============================================================================================
	// Helpers
	// ==============================================================================================

	/**
	 * Installs a package from a git URL into the given directory.
	 */
	private void function install( required string packageId, required string directory, boolean verbose=false ) {
		var installCommand = command( "package install" ).params(
			ID        = arguments.packageId,
			directory = arguments.directory,
			save      = false,
			lock      = false
		);
		if( arguments.verbose ) {
			installCommand.flags( "verbose" );
		}
		installCommand.run();
	}

	/**
	 * Resolves a git package by calling the endpoint directly.
	 *
	 * The `package install` command terminates the whole task process when a clone fails, so the
	 * error tests have to drive the endpoint instead of the command layer.  The endpoint logs
	 * through the interactive job, which needs an active job when not run from inside a command.
	 */
	private any function resolvePackage( required string packageId, required string workingDirectory ) {
		var endpointData = getInstance( "endpointService" ).resolveEndpoint( arguments.packageId, arguments.workingDirectory );
		var job = getInstance( "interactiveJob" );
		job.start( "Resolving #arguments.packageId#", 1 );
		try {
			return endpointData.endpoint.resolvePackage( endpointData.package, arguments.workingDirectory );
		} finally {
			job.complete();
		}
	}

	/**
	 * Opens an SSH transport for a URL using a throw-away repository, so the transport callback can
	 * be exercised without performing a clone.
	 */
	private any function sshTransportFor( required string url ) {
		var workTree = createObject( "java", "java.io.File" ).init( scratchDirectory( "transport-repo" ) );
		var gitDirectory = createObject( "java", "java.io.File" ).init( workTree, ".git" );

		var builder = createObject( "java", "org.eclipse.jgit.storage.file.FileRepositoryBuilder" ).init();
		builder.setGitDir( gitDirectory );
		builder.setWorkTree( workTree );
		var repository = builder.build();
		repository.create();

		var uri = createObject( "java", "org.eclipse.jgit.transport.URIish" ).init( arguments.url );
		return createObject( "java", "org.eclipse.jgit.transport.Transport" ).open( repository, uri );
	}

	/**
	 * Returns a clean scratch directory beneath this CFC, creating it if needed.
	 */
	private string function scratchDirectory( required string name ) {
		var path = getDirectoryFromPath( getCurrentTemplatePath() ) & "scratch/" & arguments.name;
		if( directoryExists( path ) ) {
			directoryDelete( path, true );
		}
		directoryCreate( path, true );
		return path;
	}

	// ==============================================================================================
	// Assertions
	// ==============================================================================================

	/**
	 * Asserts a package directory exists beneath the install target and is not empty.
	 */
	private void function assertPackageInstalled( required string directory, required string packageName ) {
		var packagePath = arguments.directory & "/" & arguments.packageName;
		if( !directoryExists( packagePath ) ) {
			var found = directoryList( arguments.directory, false, "name" );
			error( "Expected [#arguments.packageName#] to be installed under [#arguments.directory#], found [#found.toList()#]." );
		}

		var contents = directoryList( packagePath, false, "name" );
		if( !contents.len() ) {
			error( "The installed package directory [#packagePath#] is empty." );
		}
	}

	private void function assertTrue( required boolean condition, required string message ) {
		if( !arguments.condition ) {
			error( arguments.message );
		}
	}

	private void function assertEquals( required any expected, required any actual, string message="" ) {
		if( arguments.expected == arguments.actual ) {
			return;
		}

		var label = len( arguments.message ) ? arguments.message : "assertion";
		error( "#label# — expected [#arguments.expected#], received [#arguments.actual#]." );
	}

	private void function assertClassPresent( required string className, required string message ) {
		try {
			createObject( "java", arguments.className );
		} catch( any e ) {
			error( arguments.message );
		}
	}

	private void function assertClassAbsent( required string className, required string message ) {
		try {
			createObject( "java", arguments.className );
		} catch( any e ) {
			return;
		}

		error( arguments.message );
	}

	/**
	 * Runs the callback and returns the thrown error message, or an empty string if nothing threw.
	 */
	private string function catchThrown( required any callback ) {
		try {
			arguments.callback();
		} catch( any e ) {
			// The endpoints put a short summary in message and the underlying transport causes in
			// detail, so join both to give assertions everything that was surfaced to the user.
			return e.message & " " & ( e.detail ?: "" );
		}

		return "";
	}

	/**
	 * Runs the callback and returns the thrown message, failing the test if nothing was thrown.
	 */
	private string function assertThrows( required any callback ) {
		var message = catchThrown( arguments.callback );
		if( !message.len() ) {
			error( "Expected the callback to throw, but it completed successfully." );
		}
		return message;
	}

}
