/**
 * Tests for the `maven:` endpoint.
 *
 * Every assertion in this file is taken from a documented behavior in `src/maven-docs.md` —
 * the doc is the spec, not the implementation.
 *
 * Run from this directory with:
 *
 *     box task run taskFile=Task.cfc
 *
 * All generated output goes under `scratch/` (gitignored); nothing tracked in the repo is
 * modified.  Network access is required for anything not already in CommandBox's artifact
 * cache or `~/.m2/repository`.
 *
 * Intentionally NOT covered here (see the "Known limitations" and "Artifact cache" sections
 * of the docs): `snapshots` (needs a third-party snapshot repo), checksum tampering/missing
 * checksum failures, the `~/.m2/repository` fallback, network timeouts, and the verbose
 * resolution trail.
 */
component {

	/**
	 * Discovers and runs every `@test`-annotated function in this CFC.
	 */
	function run( boolean verbose=false ) {
		variables.failures = [];
		var testFunctions = this.$bx.meta.functions.filter( function( functionMetadata ) {
			return functionMetadata.annotations.keyExists( "test" );
		} );

		testFunctions.each( function( functionMetadata ) {
			print.line().yellowLine( "── Running #functionMetadata.name# ──" ).toConsole();
			try {
				invoke( this, functionMetadata.name, { "verbose" : verbose } );
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
		print.line( "Maven endpoint tests: #testFunctions.len() - variables.failures.len()# passed, #variables.failures.len()# failed." ).toConsole();
		variables.failures.each( function( failure ) {
			print.redLine( "✗ #failure.name#: #failure.message#" ).toConsole();
		} );

		if( variables.failures.len() ) {
			error( "#variables.failures.len()# Maven endpoint test(s) failed." );
		}
	}

	// ==============================================================================================
	// Endpoint ID format, exact versions, and default (dedicated) install mode
	// ==============================================================================================

	/**
	 * Doc: `maven:[repo|]groupId:artifactId[:version]`, and "Maven installs use `dedicated` mode by
	 * default. In dedicated mode, each artifact is installed in its own package directory with its
	 * generated box.json."
	 *
	 * @test
	 */
	function exactVersionDedicatedDescriptor( boolean verbose=false ) {
		var result = resolvePackage( "maven:org.apache.commons:commons-lang3:3.14.0", "", arguments.verbose );
		var boxJSON = result.descriptor;

		assertEquals( "org.apache.commons:commons-lang3", boxJSON.slug, "slug" );
		assertEquals( "org.apache.commons:commons-lang3.jar", boxJSON.name, "name" );
		assertEquals( "3.14.0", boxJSON.version, "version" );
		assertEquals( "jars", boxJSON.type, "type" );
		assertEquals( "dedicated", boxJSON.maven.installMode, "default install mode" );
		assertEquals( true, boxJSON.createPackageDirectory, "dedicated installs create a package directory" );
		assertEquals( "org.apache.commons-commons-lang3", boxJSON.packageDirectory, "packageDirectory" );
		assertJarExists( result.path, "commons-lang3-3.14.0.jar" );
	}

	// ==============================================================================================
	// Flag: installMode (and its precedence)
	// ==============================================================================================

	/**
	 * Doc: "Use `shared` mode when several JARs should be bundled into one directory such as `libs/`",
	 * "In shared mode, all JARs are placed directly in that directory", and "The generated box.json is
	 * not copied to the shared destination."
	 *
	 * @test
	 */
	function sharedModeBundlesEverythingInOneDirectory( boolean verbose=false ) {
		clearArtifactCache( "io.undertow", "undertow-core", "2.3.19.Final" );
		var target = scratchDirectory( "shared-mode" ) & "/libs";
		installPackage( "maven:io.undertow:undertow-core:2.3.19.Final?installMode=shared", target );

		var jars = directoryList( target, false, "array", "*.jar" );
		assertTrue( jars.len() >= 2, "shared mode must place the artifact and its transitives directly in the shared directory, found #jars.len()# JAR(s)" );

		var nestedDirectories = directoryList( target, false, "array" ).filter( ( item ) => directoryExists( item ) );
		assertEquals( 0, nestedDirectories.len(), "shared mode must not create nested package directories beneath the shared destination" );
		assertFalse( fileExists( target & "/box.json" ), "the generated box.json must not be copied into the shared destination" );
	}

	/**
	 * Doc: "In dedicated mode, each artifact is installed in its own package directory with its
	 * generated box.json" — exercised end-to-end through `package install` (and therefore
	 * `PackageService`).
	 *
	 * @test
	 */
	function dedicatedModeUsesPackageDirectory( boolean verbose=false ) {
		var target = scratchDirectory( "dedicated-mode" ) & "/libs";
		installPackage( "maven:org.apache.commons:commons-lang3:3.14.0?transitive=false", target );

		assertTrue( fileExists( target & "/org.apache.commons-commons-lang3/commons-lang3-3.14.0.jar" ), "expected the JAR in a groupId-artifactId package directory" );
		assertTrue( fileExists( target & "/org.apache.commons-commons-lang3/box.json" ), "dedicated installs must write the generated box.json" );
	}

	/**
	 * Doc: "`maven.installDirectory` overrides the normal JAR install convention for every Maven
	 * artifact" and "Project `maven.installDirectory` takes precedence over
	 * `endpoints.maven.installDirectory`."
	 *
	 * @test
	 */
	function projectInstallDirectoryIsHonored( boolean verbose=false ) {
		var projectPath = scratchDirectory( "project-install-directory" );
		writeProjectDescriptor( projectPath, {
			"name"    : "maven-project-install-directory",
			"version" : "1.0.0",
			"maven"   : { "installDirectory" : "maven-libs" }
		} );

		var result = resolvePackage( "maven:org.apache.commons:commons-lang3:3.14.0?transitive=false", projectPath, arguments.verbose );
		assertEquals( "maven-libs", result.descriptor.directory, "the project maven.installDirectory must be used" );
	}

	/**
	 * Doc install-mode precedence: "1. Endpoint flag: `?installMode=shared` 2. Project `box.json`:
	 * `maven.installMode` ... 4. Default: `dedicated`".
	 *
	 * @test
	 */
	function installModePrecedence( boolean verbose=false ) {
		var projectPath = scratchDirectory( "project-install-mode" );
		writeProjectDescriptor( projectPath, {
			"name"    : "maven-project-install-mode",
			"version" : "1.0.0",
			"maven"   : { "installMode" : "shared" }
		} );

		var fromProject = resolvePackage( "maven:org.apache.commons:commons-lang3:3.14.0?transitive=false", projectPath, arguments.verbose );
		assertEquals( "shared", fromProject.descriptor.maven.installMode, "the project maven.installMode must be used when no flag is present" );

		var fromFlag = resolvePackage( "maven:org.apache.commons:commons-lang3:3.14.0?transitive=false&installMode=dedicated", projectPath, arguments.verbose );
		assertEquals( "dedicated", fromFlag.descriptor.maven.installMode, "the endpoint flag must override the project maven.installMode" );
	}

	// ==============================================================================================
	// Flags: transitive / scopes / optional / exclude / classifier
	// ==============================================================================================

	/**
	 * Doc: "`transitive` — Set `false` to install just the requested jar, skipping dep resolution."
	 *
	 * @test
	 */
	function transitiveFalseSkipsDependencyResolution( boolean verbose=false ) {
		clearArtifactCache( "io.undertow", "undertow-core", "2.3.19.Final" );
		var result = resolvePackage( "maven:io.undertow:undertow-core:2.3.19.Final?transitive=false", "", arguments.verbose );

		assertEquals( 0, result.descriptor.dependencies.len(), "transitive=false must skip dependency resolution" );
		assertEquals( 0, result.descriptor.installPaths.len(), "transitive=false must produce no install paths" );
		assertJarExists( result.path, "undertow-core-2.3.19.Final.jar" );
	}

	/**
	 * Doc: "Dedicated installs instead give each transitive its own `groupId-artifactId` directory
	 * beneath its parent artifact directory", and `dependencies`/`installPaths` must use matching
	 * canonical `groupId:artifactId` keys (never the hyphenated form).
	 *
	 * @test
	 */
	function dedicatedTransitivesUseCanonicalKeys( boolean verbose=false ) {
		clearArtifactCache( "org.jboss.threads", "jboss-threads", "3.9.2" );
		var boxJSON = resolvePackage( "maven:org.jboss.threads:jboss-threads:3.9.2", "", arguments.verbose ).descriptor;

		assertTrue( boxJSON.dependencies.len() > 0, "expected transitive dependencies for jboss-threads" );
		for( var key in boxJSON.dependencies ) {
			assertTrue( reFind( "^[^:]+:[^:]+$", key ) != 0, "dependency keys must be canonical groupId:artifactId, got [#key#]" );
			assertTrue( boxJSON.installPaths.keyExists( key ), "installPaths must use the same canonical keys as dependencies (missing [#key#])" );
			assertEquals( replace( key, ":", "-", "all" ), boxJSON.installPaths[ key ], "dedicated transitive install paths must be groupId-artifactId" );
			assertTrue( boxJSON.dependencies[ key ].startsWith( "maven:" ), "generated transitives must be maven: endpoint IDs, got [#boxJSON.dependencies[key]#]" );
			assertTrue( boxJSON.dependencies[ key ].find( "|" ) == 0, "generated transitives must not pin the parent's repo, got [#boxJSON.dependencies[key]#]" );
		}
	}

	/**
	 * Doc: "`test` / `provided` / `system` scope — only `compile` and `runtime` are installed by
	 * default (override with the `scopes` flag above)".  jboss-threads declares its test libraries
	 * with `test` scope.
	 *
	 * @test
	 */
	function scopesFlagControlsScopeFiltering( boolean verbose=false ) {
		clearArtifactCache( "org.jboss.threads", "jboss-threads", "3.9.2" );
		var defaultScopes = resolvePackage( "maven:org.jboss.threads:jboss-threads:3.9.2", "", arguments.verbose );
		assertFalse(
			defaultScopes.descriptor.dependencies.keyExists( "org.junit.jupiter:junit-jupiter" ),
			"test-scoped dependencies must be excluded by default"
		);

		clearArtifactCache( "org.jboss.threads", "jboss-threads", "3.9.2" );
		var withTestScope = resolvePackage( "maven:org.jboss.threads:jboss-threads:3.9.2?scopes=runtime,compile,test", "", arguments.verbose );
		assertTrue(
			withTestScope.descriptor.dependencies.keyExists( "org.junit.jupiter:junit-jupiter" ),
			"adding test to scopes must pull the test-scoped dependencies in"
		);
	}

	/**
	 * Doc: "`<optional>true</optional>` deps — Maven marks these as non-transitive; we honor it by
	 * default (override with the `optional` flag above)."  logback-classic declares javax.mail:mail
	 * as optional.
	 *
	 * @test
	 */
	function optionalFlagControlsOptionalDependencies( boolean verbose=false ) {
		clearArtifactCache( "ch.qos.logback", "logback-classic", "1.2.13" );
		var withoutOptional = resolvePackage( "maven:ch.qos.logback:logback-classic:1.2.13", "", arguments.verbose );
		assertFalse( withoutOptional.descriptor.dependencies.keyExists( "javax.mail:mail" ), "optional dependencies must be excluded by default" );

		clearArtifactCache( "ch.qos.logback", "logback-classic", "1.2.13" );
		var withOptional = resolvePackage( "maven:ch.qos.logback:logback-classic:1.2.13?optional=true", "", arguments.verbose );
		assertTrue( withOptional.descriptor.dependencies.keyExists( "javax.mail:mail" ), "optional=true must pull optional dependencies in" );
	}

	/**
	 * Doc "Combining flags": allow the optional deps of logback-classic, but still exclude two specific
	 * ones — "`javax.mail:mail` and `org.codehaus.janino:janino` are both correctly excluded despite
	 * `optional=true` re-enabling optional deps in general."
	 *
	 * @test
	 */
	function combinedFlagsStillHonorExclude( boolean verbose=false ) {
		clearArtifactCache( "ch.qos.logback", "logback-classic", "1.2.13" );
		var boxJSON = resolvePackage(
			"maven:ch.qos.logback:logback-classic:1.2.13?optional=true&exclude=javax.mail:mail,org.codehaus.janino:janino",
			"",
			arguments.verbose
		).descriptor;

		assertFalse( boxJSON.dependencies.keyExists( "javax.mail:mail" ), "excluded optional dependency must stay excluded" );
		assertFalse( boxJSON.dependencies.keyExists( "org.codehaus.janino:janino" ), "excluded optional dependency must stay excluded" );
		assertTrue( boxJSON.dependencies.keyExists( "javax.servlet:javax.servlet-api" ), "the remaining optional dependency must still be installed" );
	}

	/**
	 * Doc: "`?exclude=` flag — applies uniformly to the entire subtree. It's automatically re-stamped
	 * onto every generated transitive dependency's own endpoint ID as resolution recurses."
	 *
	 * @test
	 */
	function excludeFlagIsReStampedOnEveryTransitive( boolean verbose=false ) {
		clearArtifactCache( "org.jboss.threads", "jboss-threads", "3.9.2" );
		var boxJSON = resolvePackage( "maven:org.jboss.threads:jboss-threads:3.9.2?exclude=org.jboss.logging:jboss-logging", "", arguments.verbose ).descriptor;

		assertFalse( boxJSON.dependencies.keyExists( "org.jboss.logging:jboss-logging" ), "the excluded artifact must not appear as a dependency" );
		for( var key in boxJSON.dependencies ) {
			assertTrue(
				boxJSON.dependencies[ key ].findNoCase( "exclude=org.jboss.logging:jboss-logging" ) != 0,
				"excludes must be re-stamped onto [#key#], got [#boxJSON.dependencies[key]#]"
			);
		}
	}

	/**
	 * Doc: "`classifier` — Select a JAR variant such as `sources` ... This resolves
	 * `undertow-core-2.3.18.Final-sources.jar`."
	 *
	 * @test
	 */
	function classifierSelectsPublishedJarVariant( boolean verbose=false ) {
		var result = resolvePackage( "maven:io.undertow:undertow-core:2.3.18.Final?classifier=sources&transitive=false", "", arguments.verbose );
		assertJarExists( result.path, "undertow-core-2.3.18.Final-sources.jar" );
	}

	/**
	 * Doc: "If the requested classifier is not published for the selected version, installation fails;
	 * CommandBox does not silently fall back to the unclassified JAR."
	 *
	 * @test
	 */
	function unpublishedClassifierFails( boolean verbose=false ) {
		var verboseFlag = arguments.verbose;
		assertThrows(
			function() {
				resolvePackage( "maven:io.undertow:undertow-core:2.3.18.Final?classifier=notreal&transitive=false", "", verboseFlag );
			},
			"an unpublished classifier must fail rather than fall back to the plain JAR"
		);
	}

	// ==============================================================================================
	// Repo resolution and version handling
	// ==============================================================================================

	/**
	 * Doc: "Force resolution from a specific URL only":
	 * `install maven:https://repo1.maven.org/maven2/|org.apache.commons:commons-lang3:3.14.0`.
	 *
	 * NOTE: the GAV below must be absent from the artifact cache, since exact versions short-circuit
	 * straight to the cache without consulting any repo.
	 *
	 * @test
	 */
	function repoPrefixResolvesFromThatRepo( boolean verbose=false ) {
		var result = resolvePackage( "maven:https://repo1.maven.org/maven2/|org.apache.commons:commons-csv:1.10.0?transitive=false", "", arguments.verbose );
		assertEquals( "1.10.0", result.descriptor.version, "a repo-prefixed ID must resolve from the given URL" );
	}

	/**
	 * Doc: "When the endpoint ID includes a `repo` segment (alias or URL), **only** that repo is
	 * consulted. ... We do not fall back to other repos if the requested one doesn't have the artifact."
	 *
	 * A reachable-but-404ing path is used so the test isolates the "no fall-back" rule from connection
	 * failures.  NOTE: same cache caveat as above.
	 *
	 * @test
	 */
	function repoPrefixDoesNotFallBackToOtherRepos( boolean verbose=false ) {
		var verboseFlag = arguments.verbose;
		assertThrows(
			function() {
				resolvePackage( "maven:https://repo1.maven.org/maven2/does-not-exist/|org.apache.commons:commons-collections4:4.4?transitive=false", "", verboseFlag );
			},
			"a repo-prefixed ID must only consult the requested repo"
		);
	}

	/**
	 * Doc: "A per-project entry with the same alias name as a global (or built-in) entry overrides its
	 * URL ... CommandBox tried the bogus URL first, then correctly fell through to the next registered
	 * repo after it failed. Per-project entries not present globally are simply appended to the list."
	 *
	 * A reachable-but-404ing path is used for the override rather than an unresolvable host, and the
	 * version is left off (STABLE) so resolution is metadata-driven: that is the path where a failed
	 * repo lookup is reported as a fall-back signal.  For an *exact* version the endpoint skips the
	 * metadata check entirely, so a failing repo aborts the install instead of falling through — see
	 * `getArtifactFromRepo()`.
	 *
	 * NOTE: the GAV below must be absent from the artifact cache AND ~/.m2/repository, otherwise a
	 * local source wins and no repo is consulted at all.
	 *
	 * @test
	 */
	function projectRepoOverrideFallsThroughToNextRepo( boolean verbose=false ) {
		var projectPath = scratchDirectory( "project-repo-override" );
		writeProjectDescriptor( projectPath, {
			"name"    : "maven-project-repo-override",
			"version" : "1.0.0",
			"maven"   : {
				"repositories" : {
					"mavenCentral"      : "https://repo1.maven.org/maven2/does-not-exist/",
					"additionalCentral" : "https://maven-central.storage.googleapis.com/maven2/"
				}
			}
		} );

		var result = resolvePackage( "maven:org.apache.commons:commons-text?transitive=false", projectPath, arguments.verbose );
		assertTrue( result.descriptor.version.len() != 0, "resolution must fall through to the next registered repo and pick a concrete version" );
		assertFalse(
			findNoCase( "SNAPSHOT", result.descriptor.version ) != 0,
			"STABLE fall-through must not resolve to a SNAPSHOT, got [#result.descriptor.version#]"
		);
	}

	/**
	 * Doc: "Omitting the version resolves to the artifact's `<release>` from `maven-metadata.xml`" and
	 * "SNAPSHOT versions are always excluded from `STABLE` resolution".  Also: "`2.3.x` — x-range —
	 * highest 2.3.*" and "`~2.3.0` — tilde-range — highest 2.3.*".
	 *
	 * @test
	 */
	function stableAndRangeVersionsResolveToConcreteVersions( boolean verbose=false ) {
		var stable = resolvePackage( "maven:org.apache.commons:commons-lang3", "", arguments.verbose );
		assertTrue(
			reFind( "^[0-9]+(\.[0-9]+)*(?:[-+][0-9A-Za-z.-]+)?$", stable.descriptor.version ) != 0,
			"STABLE must resolve to a concrete version, got [#stable.descriptor.version#]"
		);
		assertFalse( findNoCase( "SNAPSHOT", stable.descriptor.version ) != 0, "STABLE must never resolve to a SNAPSHOT" );

		var xRange = resolvePackage( "maven:org.apache.commons:commons-lang3:3.14.x", "", arguments.verbose );
		assertTrue( xRange.descriptor.version.startsWith( "3.14." ), "x-range must pick the highest 3.14.*, got [#xRange.descriptor.version#]" );

		var tildeRange = resolvePackage( "maven:org.apache.commons:commons-lang3:~3.14.0", "", arguments.verbose );
		assertTrue( tildeRange.descriptor.version.startsWith( "3.14." ), "tilde-range must pick the highest 3.14.*, got [#tildeRange.descriptor.version#]" );
	}

	/**
	 * Doc: "The endpoint still works fully offline for already-cached exact versions — no network calls
	 * happen at all in that case."
	 *
	 * @test
	 */
	function offlineModeServesCachedExactVersion( boolean verbose=false ) {
		// Prime the artifact cache so the offline run has something to serve.
		resolvePackage( "maven:org.apache.commons:commons-lang3:3.14.0", "", arguments.verbose );

		var configService = getInstance( "configService" );
		var originalOfflineMode = configService.getSetting( "offlineMode", false );
		try {
			configService.setSetting( "offlineMode", true, false, true );
			var result = resolvePackage( "maven:org.apache.commons:commons-lang3:3.14.0", "", arguments.verbose );
			assertEquals( "3.14.0", result.descriptor.version, "an already-cached exact version must resolve while offline" );
		} finally {
			configService.setSetting( "offlineMode", originalOfflineMode, false, true );
		}
	}

	// ==============================================================================================
	// Artifact cache / checksum verification (local throw-away Maven repo)
	// ==============================================================================================

	/**
	 * Doc: "Maven JARs are verified against the repository's `.sha256` checksum when available."
	 *
	 * @test
	 */
	function checksumMatchAllowsInstall( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			var jarBytes = "local-repo-demo-jar";
			writeRepoFile( repo, "org/example/demo/1.0.0/demo-1.0.0.jar", jarBytes );
			writeRepoFile( repo, "org/example/demo/1.0.0/demo-1.0.0.jar.sha256", sha256Of( jarBytes ) );
			writeRepoFile( repo, "org/example/demo/1.0.0/demo-1.0.0.pom", pom( "org.example", "demo", "1.0.0" ) );
			clearArtifactCache( "org.example", "demo", "1.0.0" );

			var result = resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0?transitive=false", "", arguments.verbose );

			assertEquals( "1.0.0", result.descriptor.version );
			assertJarExists( result.path, "demo-1.0.0.jar" );
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "Installation fails if a checksum is missing or does not match."
	 *
	 * @test
	 */
	function checksumMismatchFailsInstall( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			writeRepoFile( repo, "org/example/demo/1.0.0/demo-1.0.0.jar", "local-repo-demo-jar" );
			writeRepoFile( repo, "org/example/demo/1.0.0/demo-1.0.0.jar.sha256", repeatString( "0", 64 ) );
			clearArtifactCache( "org.example", "demo", "1.0.0" );

			var message = catchThrown( function() {
				resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0?transitive=false", "", verbose );
			} );

			assertTrue( message.len() != 0, "a mismatched checksum must fail the install" );
			assertTrue( message.findNoCase( "checksum mismatch" ) != 0, "expected a checksum mismatch error, got [#message#]" );
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "Installation fails if a checksum is missing or does not match."
	 *
	 * @test
	 */
	function missingChecksumFailsInstall( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			writeRepoFile( repo, "org/example/demo/1.0.0/demo-1.0.0.jar", "local-repo-demo-jar" );
			clearArtifactCache( "org.example", "demo", "1.0.0" );

			var message = catchThrown( function() {
				resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0?transitive=false", "", verbose );
			} );

			assertTrue( message.len() != 0, "a missing checksum must fail the install" );
			assertTrue(
				message.findNoCase( "did not provide a SHA-256 or SHA-1 checksum" ) != 0,
				"expected a missing-checksum error, got [#message#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "Maven JARs are verified against the repository's `.sha256` checksum when available,
	 * falling back to `.sha1`."
	 *
	 * @test
	 */
	function sha1FallbackAllowsInstall( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			var jarBytes = "local-repo-demo-jar";
			writeRepoFile( repo, "org/example/demo/1.0.0/demo-1.0.0.jar", jarBytes );
			writeRepoFile( repo, "org/example/demo/1.0.0/demo-1.0.0.jar.sha1", hash( jarBytes, "SHA-1" ) );
			clearArtifactCache( "org.example", "demo", "1.0.0" );

			var result = resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0?transitive=false", "", arguments.verbose );

			assertJarExists( result.path, "demo-1.0.0.jar" );
		} finally {
			stopLocalRepo( repo );
		}
	}

	// ==============================================================================================
	// POM parsing: version ranges, dependencyManagement, placeholders, exclusions
	// ==============================================================================================

	/**
	 * Doc: "When parsing a downloaded POM's transitive dependencies, CommandBox translates Maven's
	 * bracket notation into the semver equivalent before storing them in the child `box.json`":
	 * `[1.0,2.0)` → `>=1.0 <2.0` and `(1.0,2.0]` → `>1.0 <=2.0`.
	 *
	 * @test
	 */
	function mavenBracketRangesTranslateToSemver( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishDemoArtifact( repo, pom(
				groupId      = "org.example",
				artifactId   = "demo",
				version      = "1.0.0",
				dependencies = dependency( "org.example", "bracketchild", "[1.0,2.0)" )
					& dependency( "org.example", "parenchild", "(1.0,2.0]" )
			) );

			var dependencies = resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0", "", arguments.verbose ).descriptor.dependencies;

			assertTrue(
				dependencies[ "org.example:bracketchild" ].find( ">=1.0 <2.0" ) != 0,
				"[1.0,2.0) must become [>=1.0 <2.0], got [#dependencies[ "org.example:bracketchild" ] ?: "nothing"#]"
			);
			assertTrue(
				dependencies[ "org.example:parenchild" ].find( ">1.0 <=2.0" ) != 0,
				"(1.0,2.0] must become [>1.0 <=2.0], got [#dependencies[ "org.example:parenchild" ] ?: "nothing"#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: the Maven↔semver table lists single-version brackets: `[1.0]` → "(exact) `1.0`".
	 *
	 * FAILS: `convertMavenToNpmVersionRange()` requires a comma, so a single-version bracket throws
	 * `Invalid version range format` and the dependency never resolves. See "Known broken behaviors"
	 * in `src/maven-docs.md`.
	 *
	 * @test
	 */
	function bracketExactRangeTranslatesToExactVersion( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishDemoArtifact( repo, pom(
				groupId      = "org.example",
				artifactId   = "demo",
				version      = "1.0.0",
				dependencies = dependency( "org.example", "exactchild", "[1.0]" )
			) );

			var message = catchThrown( function() {
				resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0", "", verbose );
			} );
			assertFalse(
				message.len() != 0,
				"documented behavior: [1.0] must translate to the exact version 1.0, but resolution failed with [#message#]"
			);

			var dependencies = resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0", "", arguments.verbose ).descriptor.dependencies;
			assertTrue( dependencies.keyExists( "org.example:exactchild" ), "the [1.0] dependency must be present" );
			assertEquals(
				"1.0",
				listGetAt( dependencies[ "org.example:exactchild" ].listFirst( "?" ), 4, ":" ),
				"[1.0] must translate to the exact version 1.0"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "Entries in `<dependencyManagement>` are not installed themselves. They are collected into
	 * a lookup map ... and used solely to fill in missing `<version>` / `<scope>` / `<type>` on real
	 * `<dependencies>` elsewhere in the same POM."
	 *
	 * @test
	 */
	function dependencyManagementFillsMissingVersions( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishDemoArtifact( repo, pom(
				groupId              = "org.example",
				artifactId           = "demo",
				version              = "1.0.0",
				dependencyManagement = '<dependencyManagement><dependencies>'
						& '<dependency><groupId>org.example</groupId><artifactId>managed</artifactId><version>9.9.9</version></dependency>'
						& '</dependencies></dependencyManagement>',
				// The real dependency carries no version - it must come from the managed entry.
				dependencies = dependency( "org.example", "managed" )
			) );

			var dependencies = resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0", "", arguments.verbose ).descriptor.dependencies;

			assertTrue( dependencies.keyExists( "org.example:managed" ), "the managed dependency must be present" );
			assertTrue(
				dependencies[ "org.example:managed" ].find( ":9.9.9" ) != 0,
				"the version must come from dependencyManagement, got [#dependencies[ "org.example:managed" ]#]"
			);
			assertFalse(
				dependencies.keyExists( "org.example:managed" ) && dependencies[ "org.example:managed" ].find( "managed:managed" ) != 0,
				"a dependencyManagement entry must not leak in as its own dependency"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "`${...}` placeholders in POM values are resolved by walking the parent chain ... Custom
	 * `<properties>` — looked up across the chain (child properties shadow parent)."
	 *
	 * @test
	 */
	function propertyPlaceholdersAreResolved( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishDemoArtifact( repo, pom(
				groupId      = "org.example",
				artifactId   = "demo",
				version      = "1.0.0",
				properties   = '<properties><demo.child.version>4.5.6</demo.child.version></properties>',
				dependencies = dependency( "org.example", "propchild", '${demo.child.version}' )
			) );

			var dependencies = resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0", "", arguments.verbose ).descriptor.dependencies;

			assertTrue( dependencies.keyExists( "org.example:propchild" ), "the placeholder dependency must be present" );
			assertTrue(
				dependencies[ "org.example:propchild" ].find( ":4.5.6" ) != 0,
				"the placeholder must resolve to the property value, got [#dependencies[ "org.example:propchild" ]#]"
			);
			assertTrue(
				dependencies[ "org.example:propchild" ].find( "${" ) == 0,
				"no unresolved placeholder may remain, got [#dependencies[ "org.example:propchild" ]#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "Deps with no resolvable version — after `<dependencyManagement>` inheritance from
	 * the entire parent chain, a dep still missing a version **fails the install** with a message
	 * naming the `groupId:artifactId`. It is never silently dropped."
	 *
	 * @test
	 */
	function dependencyWithoutResolvableVersionFailsInstall( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishDemoArtifact( repo, pom(
				groupId      = "org.example",
				artifactId   = "demo",
				version      = "1.0.0",
				dependencies = dependency( "org.example", "keepme", "1.0.0" )
					& dependency( "org.example", "noversion" )
			) );

			var message = "";
			try {
				resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0", "", arguments.verbose );
			} catch( any e ) {
				message = e.message;
			}

			assertTrue(
				message.findNoCase( "org.example:noversion" ) != 0,
				"the failure must name the unresolved dependency, got [#message#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "When the same `groupId:artifactId` is declared more than once in a single
	 * `<dependencyManagement>` block, the **first** declaration wins — Maven's duplicate handling.
	 * This matters in practice: `io.undertow:undertow-parent` manages `io.undertow:undertow-core`
	 * once as `compile` and again as `test`, and only keeping the first stops the test scope from
	 * silently demoting the dependency."
	 *
	 * @test
	 */
	function duplicateDependencyManagementEntriesKeepTheFirst( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishDemoArtifact( repo, pom(
				groupId              = "org.example",
				artifactId           = "demo",
				version              = "1.0.0",
				dependencyManagement = '<dependencyManagement><dependencies>'
						& '<dependency><groupId>org.example</groupId><artifactId>managed</artifactId><version>1.0.0</version></dependency>'
						& '<dependency><groupId>org.example</groupId><artifactId>managed</artifactId><version>1.0.0</version><scope>test</scope></dependency>'
						& '</dependencies></dependencyManagement>',
				dependencies         = dependency( "org.example", "managed" )
			) );

			var dependencies = resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0", "", arguments.verbose ).descriptor.dependencies;

			assertTrue(
				dependencies.keyExists( "org.example:managed" ),
				"the second (test scoped) managed entry must not demote the compile dependency out of the resolve"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "`${project.version}` ... inside an ancestor's `<dependencyManagement>` resolve against
	 * **that ancestor's own coordinates**, not the POM being resolved."
	 *
	 * @test
	 */
	function ancestorDependencyManagementResolvesProjectVersion( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			// The parent manages a sibling at its own version
			publishArtifact(
				repo,
				"org.example",
				"demo-parent",
				"2.0.0",
				pom(
					groupId              = "org.example",
					artifactId           = "demo-parent",
					version              = "2.0.0",
					dependencyManagement = '<dependencyManagement><dependencies>'
							& '<dependency><groupId>org.example</groupId><artifactId>sibling</artifactId><version>${project.version}</version></dependency>'
							& '</dependencies></dependencyManagement>'
				)
			);

			// The child declares the dependency with no version at all
			publishDemoArtifact( repo, pom(
				groupId      = "org.example",
				artifactId   = "demo",
				version      = "1.0.0",
				parent       = '<parent><groupId>org.example</groupId><artifactId>demo-parent</artifactId><version>2.0.0</version></parent>',
				dependencies = dependency( "org.example", "sibling" )
			) );

			var dependencies = resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0", "", arguments.verbose ).descriptor.dependencies;

			assertTrue( dependencies.keyExists( "org.example:sibling" ), "the ancestor-managed dependency must be resolved" );
			assertTrue(
				dependencies[ "org.example:sibling" ].find( ":2.0.0" ) != 0,
				"${project.version} must resolve to the ancestor's own version, got [#dependencies[ "org.example:sibling" ]#]"
			);
			assertTrue(
				dependencies[ "org.example:sibling" ].find( "${" ) == 0,
				"no unresolved placeholder may remain, got [#dependencies[ "org.example:sibling" ]#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "**POM-native `<exclusions>`** — some libraries declare their own exclusions on a specific
	 * dependency edge ... Unlike your own `?exclude=`, a POM-declared exclusion only applies to that
	 * one dependency's own subtree, not its siblings."
	 *
	 * @test
	 */
	function pomNativeExclusionsApplyToThatEdgeOnly( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishArtifact( repo, "org.example", "dropped", "1.0.0", pom( groupId="org.example", artifactId="dropped", version="1.0.0" ) );
			publishArtifact( repo, "org.example", "kept", "1.0.0", pom( groupId="org.example", artifactId="kept", version="1.0.0" ) );
			publishArtifact( repo, "org.example", "childa", "1.0.0", pom(
				groupId      = "org.example",
				artifactId   = "childa",
				version      = "1.0.0",
				dependencies = dependency( "org.example", "dropped", "1.0.0" )
					& dependency( "org.example", "kept", "1.0.0" )
			) );

			var childWithExclusion = dependency(
				groupId    = "org.example",
				artifactId = "childa",
				version    = "1.0.0",
				exclusions = '<exclusions><exclusion><groupId>org.example</groupId><artifactId>dropped</artifactId></exclusion></exclusions>'
			);

			// demo excludes dropped on the childa edge
			publishDemoArtifact( repo, pom(
				groupId      = "org.example",
				artifactId   = "demo",
				version      = "1.0.0",
				dependencies = childWithExclusion
			) );

			var excluded = resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0", "", arguments.verbose ).descriptor.dependencies;
			assertTrue( excluded.keyExists( "org.example:kept" ), "the rest of the child's subtree must still resolve" );
			assertFalse( excluded.keyExists( "org.example:dropped" ), "the POM-declared exclusion must remove the dependency from that edge" );

			// A second artifact depends on the same child without the exclusion
			publishArtifact( repo, "org.example", "demo2", "1.0.0", pom(
				groupId      = "org.example",
				artifactId   = "demo2",
				version      = "1.0.0",
				dependencies = dependency( "org.example", "childa", "1.0.0" )
			) );

			var notExcluded = resolvePackage( "maven:#repo.url#|org.example:demo2:1.0.0", "", arguments.verbose ).descriptor.dependencies;
			assertTrue(
				notExcluded.keyExists( "org.example:dropped" ),
				"the exclusion is edge specific, so the same child must keep it when no exclusion is declared"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "exactly one version of each groupId:artifactId is installed ... otherwise the highest
	 * version requested anywhere in the graph wins."
	 *
	 * @test
	 */
	function versionsAreMediatedToTheHighestRequested( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishArtifact( repo, "org.example", "lib", "1.0.0", pom( groupId="org.example", artifactId="lib", version="1.0.0" ) );
			publishArtifact( repo, "org.example", "lib", "2.0.0", pom( groupId="org.example", artifactId="lib", version="2.0.0" ) );
			publishArtifact( repo, "org.example", "wantsold", "1.0.0", pom(
				groupId      = "org.example",
				artifactId   = "wantsold",
				version      = "1.0.0",
				dependencies = dependency( "org.example", "lib", "1.0.0" )
			) );
			publishArtifact( repo, "org.example", "wantsnew", "1.0.0", pom(
				groupId      = "org.example",
				artifactId   = "wantsnew",
				version      = "1.0.0",
				dependencies = dependency( "org.example", "lib", "2.0.0" )
			) );

			publishDemoArtifact( repo, pom(
				groupId      = "org.example",
				artifactId   = "demo",
				version      = "1.0.0",
				dependencies = dependency( "org.example", "wantsold", "1.0.0" )
					& dependency( "org.example", "wantsnew", "1.0.0" )
			) );

			var dependencies = resolvePackage( "maven:#repo.url#|org.example:demo:1.0.0", "", arguments.verbose ).descriptor.dependencies;

			assertTrue( dependencies.keyExists( "org.example:lib" ), "the mediated dependency must be resolved" );
			assertTrue(
				dependencies[ "org.example:lib" ].find( ":2.0.0" ) != 0,
				"the highest requested version must win, got [#dependencies[ "org.example:lib" ]#]"
			);
			assertTrue(
				dependencies[ "org.example:lib" ].find( ":1.0.0" ) == 0,
				"the rejected version must not be installed as well, got [#dependencies[ "org.example:lib" ]#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "a version declared directly in the project's box.json wins" over anything requested
	 * transitively.
	 *
	 * @test
	 */
	function projectPinOutranksTransitiveVersion( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishArtifact( repo, "org.example", "lib", "1.0.0", pom( groupId="org.example", artifactId="lib", version="1.0.0" ) );
			publishArtifact( repo, "org.example", "lib", "2.0.0", pom( groupId="org.example", artifactId="lib", version="2.0.0" ) );
			publishArtifact( repo, "org.example", "wantsnew", "1.0.0", pom(
				groupId      = "org.example",
				artifactId   = "wantsnew",
				version      = "1.0.0",
				dependencies = dependency( "org.example", "lib", "2.0.0" )
			) );

			publishDemoArtifact( repo, pom(
				groupId      = "org.example",
				artifactId   = "demo",
				version      = "1.0.0",
				dependencies = dependency( "org.example", "wantsnew", "1.0.0" )
			) );

			var projectDirectory = scratchDirectory( "pin-project" );
			fileWrite( projectDirectory & "/box.json", serializeJSON( {
				"name"         : "pin",
				"slug"         : "pin",
				"version"      : "1.0.0",
				"dependencies" : { "org.example:lib" : "maven:org.example:lib:1.0.0" }
			} ) );

			var dependencies = resolvePackage(
				"maven:#repo.url#|org.example:demo:1.0.0",
				projectDirectory,
				arguments.verbose
			).descriptor.dependencies;

			assertTrue( dependencies.keyExists( "org.example:lib" ), "the pinned dependency must be resolved" );
			assertTrue(
				dependencies[ "org.example:lib" ].find( ":1.0.0" ) != 0,
				"the project pin must outrank the transitive 2.0.0, got [#dependencies[ "org.example:lib" ]#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "Mediation runs over the full graph (not per subtree)" — the plan is shared by every root
	 * in the command, so two roots that want different versions of the same library both get the
	 * mediated one.
	 *
	 * @test
	 */
	function mediationSpansAllRootsInTheProject( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishLibraryVersions( repo, [ "1.0.0", "2.0.0" ] );
			publishWantsLib( repo, "wantsold", "1.0.0" );
			publishWantsLib( repo, "wantsnew", "2.0.0" );

			var projectDirectory = scratchDirectory( "mediation-project" );
			fileWrite( projectDirectory & "/box.json", serializeJSON( {
				"name"         : "mediation",
				"slug"         : "mediation",
				"version"      : "1.0.0",
				"dependencies" : {
					"org.example:wantsold" : "maven:#repo.url#|org.example:wantsold:1.0.0",
					"org.example:wantsnew" : "maven:#repo.url#|org.example:wantsnew:1.0.0"
				}
			} ) );

			var oldRoot = resolvePackage( "maven:#repo.url#|org.example:wantsold:1.0.0", projectDirectory, arguments.verbose ).descriptor;
			var newRoot = resolvePackage( "maven:#repo.url#|org.example:wantsnew:1.0.0", projectDirectory, arguments.verbose ).descriptor;

			assertTrue( oldRoot.dependencies.keyExists( "org.example:lib" ), "the older root must still depend on lib" );
			assertTrue(
				oldRoot.dependencies[ "org.example:lib" ].find( ":2.0.0" ) != 0,
				"the older root must use the mediated version, got [#oldRoot.dependencies[ "org.example:lib" ]#]"
			);
			assertTrue(
				newRoot.dependencies[ "org.example:lib" ].find( ":2.0.0" ) != 0,
				"the newer root must use the mediated version, got [#newRoot.dependencies[ "org.example:lib" ]#]"
			);
			assertTrue(
				newRoot.dependencies[ "org.example:lib" ].find( ":1.0.0" ) == 0,
				"the rejected version must not be installed as well, got [#newRoot.dependencies[ "org.example:lib" ]#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "a version declared directly in the project's box.json wins" — and adding a root/constraint
	 * mid-command re-seeds the plan instead of serving the stale one.
	 *
	 * @test
	 */
	function mediationPlanIsReseededWhenTheProjectChanges( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishLibraryVersions( repo, [ "1.0.0", "2.0.0" ] );
			publishWantsLib( repo, "wantsold", "1.0.0" );
			publishWantsLib( repo, "wantsnew", "2.0.0" );

			var projectDirectory = scratchDirectory( "reseed-project" );
			var boxJson = {
				"name"         : "reseed",
				"slug"         : "reseed",
				"version"      : "1.0.0",
				"dependencies" : {
					"org.example:wantsold" : "maven:#repo.url#|org.example:wantsold:1.0.0"
				}
			};
			fileWrite( projectDirectory & "/box.json", serializeJSON( boxJson ) );

			var singleRoot = resolvePackage( "maven:#repo.url#|org.example:wantsold:1.0.0", projectDirectory, arguments.verbose ).descriptor;
			assertTrue(
				singleRoot.dependencies[ "org.example:lib" ].find( ":1.0.0" ) != 0,
				"with one root the only requested version must win, got [#singleRoot.dependencies[ "org.example:lib" ]#]"
			);

			// A second root now requests a higher version: the plan must be rebuilt, not reused
			boxJson.dependencies[ "org.example:wantsnew" ] = "maven:#repo.url#|org.example:wantsnew:1.0.0";
			fileWrite( projectDirectory & "/box.json", serializeJSON( boxJson ) );

			var reseeded = resolvePackage( "maven:#repo.url#|org.example:wantsold:1.0.0", projectDirectory, arguments.verbose ).descriptor;
			assertTrue(
				reseeded.dependencies[ "org.example:lib" ].find( ":2.0.0" ) != 0,
				"adding a root must re-mediate, got [#reseeded.dependencies[ "org.example:lib" ]#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * A cached package carries the dependency list from when it was cached.  The plan for the
	 * current command must replace it, or a warm cache silently reinstates rejected versions.
	 *
	 * @test
	 */
	function cachedPackageDependenciesFollowTheCurrentPlan( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishLibraryVersions( repo, [ "1.0.0", "2.0.0" ] );
			publishWantsLib( repo, "wantsnew", "2.0.0" );
			clearArtifactCache( "org.example", "wantsnew", "1.0.0" );

			var projectDirectory = scratchDirectory( "cached-plan-project" );
			var boxJson = {
				"name"         : "cachedplan",
				"slug"         : "cachedplan",
				"version"      : "1.0.0",
				"dependencies" : {
					"org.example:wantsnew" : "maven:#repo.url#|org.example:wantsnew:1.0.0"
				}
			};
			fileWrite( projectDirectory & "/box.json", serializeJSON( boxJson ) );

			// Cold resolve: the transitive 2.0.0 is the mediated winner
			var cold = resolvePackage( "maven:#repo.url#|org.example:wantsnew:1.0.0", projectDirectory, arguments.verbose ).descriptor;
			assertTrue( cold.dependencies[ "org.example:lib" ].find( ":2.0.0" ) != 0, "expected 2.0.0 from a cold resolve" );

			// The project now pins 1.0.0.  The artifact itself is cached, but the descriptor's
			// dependency list must follow the new plan.
			boxJson.dependencies[ "org.example:lib" ] = "maven:org.example:lib:1.0.0";
			fileWrite( projectDirectory & "/box.json", serializeJSON( boxJson ) );

			var warm = resolvePackage( "maven:#repo.url#|org.example:wantsnew:1.0.0", projectDirectory, arguments.verbose ).descriptor;
			assertTrue(
				warm.dependencies[ "org.example:lib" ].find( ":1.0.0" ) != 0,
				"a cached package must not replay its old dependency list, got [#warm.dependencies[ "org.example:lib" ]#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	// ==============================================================================================
	// Artifact cache, global config, offline mode and logging
	// ==============================================================================================

	/**
	 * Doc: "The cache is keyed **purely by `groupId:artifactId:version` (GAV)** — the repo that served
	 * it is **not** part of the key."
	 *
	 * A local repo that serves the same GAV with deliberately different bytes must not be able to
	 * change what an already-cached exact version resolves to.
	 *
	 * @test
	 */
	function cacheKeyIgnoresServingRepo( boolean verbose=false ) {
		clearArtifactCache( "org.apache.commons", "commons-lang3", "3.14.0" );
		var fromCentral = resolvePackage( "maven:org.apache.commons:commons-lang3:3.14.0", "", arguments.verbose );
		var cachedHash = fileHash( jarInDirectory( fromCentral.path ) );
		var cachedJarBytes = jarBytesFromCache( "org.apache.commons", "commons-lang3", "3.14.0" );
		assertEquals( cachedHash, hash( cachedJarBytes, "SHA-256" ), "the resolved JAR should match the cached one" );

		var repo = startLocalRepo();
		try {
			// Serve the identical bytes under the identical GAV from a different repo.
			publishArtifact(
				repo,
				"org.apache.commons",
				"commons-lang3",
				"3.14.0",
				pom( groupId="org.apache.commons", artifactId="commons-lang3", version="3.14.0" ),
				cachedJarBytes
			);

			var fromLocalRepo = resolvePackage(
				"maven:#repo.url#|org.apache.commons:commons-lang3:3.14.0",
				"",
				arguments.verbose
			);

			assertEquals( "3.14.0", fromLocalRepo.descriptor.version );
			assertEquals(
				cachedHash,
				fileHash( jarInDirectory( fromLocalRepo.path ) ),
				"the cached GAV must be reused regardless of which repo the ID names"
			);
			assertTrue(
				servedRequests( repo ).filter( ( line ) => line.trim().endsWith( ".jar" ) ).len() == 0,
				"the cached JAR must not be re-downloaded just because a different repo was requested, got [#servedRequests( repo ).toList( ", " )#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "On every cache hit, CommandBox rehydrates its generated descriptor with the current
	 * install mode and install directory, including its transitive dependency paths. A previous
	 * dedicated install therefore cannot cause a later shared install to create nested artifact
	 * directories, and vice versa."
	 *
	 * @test
	 */
	function cacheHitRehydratesInstallMode( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishArtifact( repo, "org.example", "rehydrate", "1.0.0", pom(
				groupId      = "org.example",
				artifactId   = "rehydrate",
				version      = "1.0.0",
				dependencies = dependency( "org.example", "rehydratechild", "1.0.0" )
			) );
			clearArtifactCache( "org.example", "rehydrate", "1.0.0" );

			var dedicated = resolvePackage( "maven:#repo.url#|org.example:rehydrate:1.0.0", "", arguments.verbose ).descriptor;
			assertEquals( "dedicated", dedicated.maven.installMode, "the first (cache-cold) resolve must be dedicated" );
			assertEquals( "org.example-rehydratechild", dedicated.installPaths[ "org.example:rehydratechild" ], "dedicated transitives get their own directory" );

			// Same GAV, so this is a cache hit - the descriptor must still be rehydrated for shared mode.
			var shared = resolvePackage( "maven:#repo.url#|org.example:rehydrate:1.0.0?installMode=shared", "", arguments.verbose ).descriptor;
			assertEquals( "shared", shared.maven.installMode, "a cache hit must rehydrate the requested install mode" );
			assertEquals( false, shared.createPackageDirectory, "shared installs must not create a nested package directory" );
			assertEquals( false, shared.persistDependencies, "shared installs must not persist transitive dependencies" );
			assertEquals( ".", shared.installPaths[ "org.example:rehydratechild" ], "shared transitives must rehydrate to the shared destination" );
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "Cache is only used for exact versions — `STABLE` and ranges always consult the remote
	 * `maven-metadata.xml` to know which concrete version to resolve to (then re-check the cache
	 * against that concrete version before downloading, so a repeat `STABLE` install of an
	 * already-resolved version still costs only one metadata fetch, not a re-download)."
	 *
	 * FAILS: the JAR is downloaded *before* the concrete version is assigned, so the cache re-check
	 * happens too late and every repeat range/`STABLE` install re-downloads the artifact. See "Known
	 * broken behaviors" in `src/maven-docs.md`.
	 *
	 * @test
	 */
	function rangeResolutionReusesCachedJar( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
				publishArtifact( repo, "org.example", "rangedemo", "2.0.0", pom( groupId="org.example", artifactId="rangedemo", version="2.0.0" ) );
				writeMavenMetadata( repo, "org.example", "rangedemo", [ "2.0.0" ] );
				clearArtifactCache( "org.example", "rangedemo", "2.0.0" );

				var first = resolvePackage( "maven:#repo.url#|org.example:rangedemo:2.0.x", "", arguments.verbose );
				assertEquals( "2.0.0", first.descriptor.version, "the range must resolve to the concrete version" );
				assertTrue( artifactIsCached( "org.example", "rangedemo", "2.0.0" ), "the resolved artifact must be cached" );

				var afterFirst = servedRequests( repo ).len();

				var second = resolvePackage( "maven:#repo.url#|org.example:rangedemo:2.0.x", "", arguments.verbose );
				assertEquals( "2.0.0", second.descriptor.version, "the repeat resolve must still resolve the range" );

				var allRequests = servedRequests( repo );
				var secondPhase = [];
				for( var index = afterFirst + 1; index <= allRequests.len(); index++ ) {
					secondPhase.append( allRequests[ index ] );
				}

				assertTrue(
					secondPhase.filter( ( line ) => line.findNoCase( "maven-metadata.xml" ) != 0 ).len() != 0,
					"documented behavior: a repeat range resolve must fetch maven-metadata.xml, got [#secondPhase.toList( ", " )#]"
				);
				assertTrue(
					secondPhase.filter( ( line ) => line.trim().endsWith( ".jar" ) ).len() == 0,
					"documented behavior: the already-resolved version must be served from cache instead of re-downloaded, but the JAR was requested again: [#secondPhase.toList( ", " )#]"
				);
		} finally {
				stopLocalRepo( repo );
		}
	}

	/**
	 * Doc install-mode precedence: "3. Global configuration: `endpoints.maven.installMode`" and
	 * "Configure a global Maven JAR destination with: `config set endpoints.maven.installDirectory=libs`".
	 *
	 * @test
	 */
	function globalConfigInstallModeAndDirectoryPrecedence( boolean verbose=false ) {
		var capturedMode = captureConfigSetting( "endpoints.maven.installMode" );
		var capturedDirectory = captureConfigSetting( "endpoints.maven.installDirectory" );
		try {
			var configService = getInstance( "configService" );
			configService.setSetting( "endpoints.maven.installMode", "shared", false, true );
			configService.setSetting( "endpoints.maven.installDirectory", "global-libs", false, true );

			var boxJSON = resolvePackage( "maven:org.apache.commons:commons-lang3:3.14.0", "", arguments.verbose ).descriptor;

			assertEquals( "shared", boxJSON.maven.installMode, "the global endpoints.maven.installMode must be honored" );
			assertEquals( "global-libs", boxJSON.directory, "the global endpoints.maven.installDirectory must be honored" );
		} finally {
			restoreConfigSetting( "endpoints.maven.installMode", capturedMode );
			restoreConfigSetting( "endpoints.maven.installDirectory", capturedDirectory );
		}
	}

	/**
	 * Doc: "Every network call checks `offlineMode` first and fails fast with a clear message
	 * (`config set offlineMode=false` to go back online) rather than timing out."
	 *
	 * @test
	 */
	function offlineModeFailsFastForUncachedArtifact( boolean verbose=false ) {
		// A GAV that is neither cached nor present in ~/.m2/repository on any likely machine.
		clearArtifactCache( "org.example", "offline-demo", "1.0.0" );
		var capturedOfflineMode = captureConfigSetting( "offlineMode" );
		try {
			getInstance( "configService" ).setSetting( "offlineMode", true, false, true );

			var message = catchThrown( function() {
				resolvePackage( "maven:org.example:offline-demo:1.0.0?transitive=false", "", verbose );
			} );

			assertTrue( message.len() != 0, "an uncached artifact must fail while offline" );
			assertTrue(
				message.findNoCase( "offline" ) != 0,
				"the failure must explain offline mode, got [#message#]"
			);
		} finally {
			restoreConfigSetting( "offlineMode", capturedOfflineMode );
		}
	}

	/**
	 * Doc: "CommandBox also checks your local Maven repository at `~/.m2/repository` ... If the exact
	 * GAV you're installing is already sitting there, CommandBox copies it straight from disk instead
	 * of downloading it again", "**Read-only** — CommandBox never writes to `~/.m2/repository`", and
	 * "The same is true if the exact version is found in your local Maven repository — no network call
	 * is needed for the jar itself."
	 *
	 * Skips (with a visible message) when this machine has no such artifact, since the precondition is
	 * local machine state.
	 *
	 * @test
	 */
	function localMavenRepositoryFallbackIsReadOnly( boolean verbose=false ) {
		var jarPath = createObject( "java", "java.lang.System" ).getProperty( "user.home" )
			& "/.m2/repository/commons-io/commons-io/2.16.1/commons-io-2.16.1.jar";

		if( !fileExists( jarPath ) ) {
			print.yellowLine( "  skipped: no ~/.m2/repository/commons-io/commons-io/2.16.1/commons-io-2.16.1.jar on this machine" ).toConsole();
			return;
		}

		var modifiedBefore = getFileInfo( jarPath ).lastmodified;
		clearArtifactCache( "commons-io", "commons-io", "2.16.1" );
		var capturedOfflineMode = captureConfigSetting( "offlineMode" );
		try {
			// Offline proves the JAR came from disk rather than the network.
			getInstance( "configService" ).setSetting( "offlineMode", true, false, true );

			var result = resolvePackage( "maven:commons-io:commons-io:2.16.1?transitive=false", "", arguments.verbose );

			assertEquals( "2.16.1", result.descriptor.version, "the local Maven repository must satisfy an exact version" );
			assertJarExists( result.path, "commons-io-2.16.1.jar" );
		} finally {
			restoreConfigSetting( "offlineMode", capturedOfflineMode );
		}

		assertEquals( modifiedBefore, getFileInfo( jarPath ).lastmodified, "CommandBox must never write to ~/.m2/repository" );
	}

	/**
	 * Doc: "Use `install --verbose` to see the resolution trail", showing "Trying repo [mavenCentral]"
	 * and "Resolved from repo [mavenCentral]" lines.
	 *
	 * @test
	 */
	function resolutionTrailIsLogged( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishArtifact( repo, "org.example", "trail", "1.0.0", pom( groupId="org.example", artifactId="trail", version="1.0.0" ) );
			clearArtifactCache( "org.example", "trail", "1.0.0" );

			var job = getInstance( "interactiveJob" );
			// Drain any job left active by an earlier test: a new job would otherwise be created as a
			// child of it and getLines() would return the parent's stale lines.
			while( job.isActive() ) {
				job.complete( false );
			}
			job.start( "Resolving maven:org.example:trail:1.0.0", 1 );
			var lines = [];
			try {
				getInstance( "endpointService" )
					.getEndpoint( "maven" )
					.resolvePackage( package="maven:#repo.url#|org.example:trail:1.0.0?transitive=false" );
				lines = job.getLines( includeAllLogs=true ).map( ( line ) => line.toAnsi() );
			} finally {
				job.complete( false );
			}

			assertTrue( lines.len() != 0, "the endpoint must collect a resolution trail" );
			assertTrue(
				lines.filter( ( line ) => line.findNoCase( "Trying repo" ) != 0 ).len() != 0,
				"expected a 'Trying repo' line, got [#lines.toList( " | " )#]"
			);
			assertTrue(
				lines.filter( ( line ) => line.findNoCase( "Resolved from repo" ) != 0 ).len() != 0,
				"expected a 'Resolved from repo' line, got [#lines.toList( " | " )#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	// ==============================================================================================
	// Known-broken behaviors - these tests assert the DOCUMENTED behavior and FAIL until the bug is
	// fixed.  Each one is listed in "Known broken behaviors" in `src/maven-docs.md`.
	// ==============================================================================================

	/**
	 * Doc: the per-install flags "override default resolution behavior for a single install" —
	 * `scopes`, `optional`, `exclude` and `transitive` decide which transitives come along.  Nothing
	 * in the docs exempts an artifact just because its GAV is cached.
	 *
	 * FAILS: a cache hit rebuilds the descriptor from the cached copy and only refreshes the install
	 * mode/directory, so the flag is silently ignored once the GAV has been resolved with different
	 * flags.
	 *
	 * @test
	 */
	function cacheHitHonorsResolutionFlags( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishArtifact( repo, "org.example", "flagdemo", "1.0.0", pom(
				groupId      = "org.example",
				artifactId   = "flagdemo",
				version      = "1.0.0",
				dependencies = dependency( "org.example", "flagchild", "1.0.0" )
			) );
			clearArtifactCache( "org.example", "flagdemo", "1.0.0" );

			var primed = resolvePackage( "maven:#repo.url#|org.example:flagdemo:1.0.0", "", arguments.verbose ).descriptor;
			assertTrue( primed.dependencies.keyExists( "org.example:flagchild" ), "the priming resolve must include the transitive" );

			// Same GAV, now with an install-specific flag: it must still apply.
			var excluded = resolvePackage(
				"maven:#repo.url#|org.example:flagdemo:1.0.0?exclude=org.example:flagchild",
				"",
				arguments.verbose
			).descriptor;

			assertFalse(
				excluded.dependencies.keyExists( "org.example:flagchild" ),
				"documented behavior: ?exclude= must drop the dependency on a cached GAV too, but the cached descriptor was returned unchanged"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "`optional` — Include `<optional>true</optional>` transitive dependencies" for a single
	 * install.  Nothing in the docs exempts an artifact whose GAV is already cached.
	 *
	 * FAILS: the cached descriptor (built with the default `optional=false`) is returned as-is, so the
	 * flag is ignored on a cache hit.
	 *
	 * @test
	 */
	function cacheHitHonorsOptionalFlag( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishArtifact( repo, "org.example", "optflag", "1.0.0", pom(
				groupId      = "org.example",
				artifactId   = "optflag",
				version      = "1.0.0",
				dependencies = dependency( groupId="org.example", artifactId="optchild", version="1.0.0", optional="true" )
			) );
			clearArtifactCache( "org.example", "optflag", "1.0.0" );

			var primed = resolvePackage( "maven:#repo.url#|org.example:optflag:1.0.0", "", arguments.verbose ).descriptor;
			assertFalse( primed.dependencies.keyExists( "org.example:optchild" ), "optional dependencies are excluded by default" );

			var withOptional = resolvePackage( "maven:#repo.url#|org.example:optflag:1.0.0?optional=true", "", arguments.verbose ).descriptor;

			assertTrue(
				withOptional.dependencies.keyExists( "org.example:optchild" ),
				"documented behavior: ?optional=true must include the optional dependency on a cached GAV too, but the cached descriptor was returned unchanged"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "`scopes` — Comma-separated list of Maven scopes to include as transitives" for a single
	 * install.  Nothing in the docs exempts an artifact whose GAV is already cached.
	 *
	 * FAILS: the cached descriptor (built with the default `runtime,compile`) is returned as-is, so the
	 * flag is ignored on a cache hit.
	 *
	 * @test
	 */
	function cacheHitHonorsScopesFlag( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishArtifact( repo, "org.example", "scopeflag", "1.0.0", pom(
				groupId      = "org.example",
				artifactId   = "scopeflag",
				version      = "1.0.0",
				dependencies = dependency( groupId="org.example", artifactId="testchild", version="1.0.0", scope="test" )
			) );
			clearArtifactCache( "org.example", "scopeflag", "1.0.0" );

			var primed = resolvePackage( "maven:#repo.url#|org.example:scopeflag:1.0.0", "", arguments.verbose ).descriptor;
			assertFalse( primed.dependencies.keyExists( "org.example:testchild" ), "test-scoped dependencies are excluded by default" );

			var withTestScope = resolvePackage(
				"maven:#repo.url#|org.example:scopeflag:1.0.0?scopes=runtime,compile,test",
				"",
				arguments.verbose
			).descriptor;

			assertTrue(
				withTestScope.dependencies.keyExists( "org.example:testchild" ),
				"documented behavior: ?scopes=...,test must include test-scoped dependencies on a cached GAV too, but the cached descriptor was returned unchanged"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "Cache is only used for exact versions — `STABLE` and ranges always consult the remote
	 * `maven-metadata.xml` ... then re-check the cache against that concrete version before
	 * downloading" — so a repeat `STABLE`/range install of an already-resolved version must work from
	 * the cache even if the repository no longer serves the JAR.
	 *
	 * FAILS: the JAR download happens before that cache re-check, so the repeat install fails with a
	 * 404 even though the artifact is cached.
	 *
	 * @test
	 */
	function repeatRangeInstallSurvivesUnpublishedJar( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishArtifact( repo, "org.example", "gone", "3.0.0", pom( groupId="org.example", artifactId="gone", version="3.0.0" ) );
			writeMavenMetadata( repo, "org.example", "gone", [ "3.0.0" ] );
			clearArtifactCache( "org.example", "gone", "3.0.0" );

			var first = resolvePackage( "maven:#repo.url#|org.example:gone:3.0.x", "", arguments.verbose );
			assertEquals( "3.0.0", first.descriptor.version, "the range must resolve to the concrete version" );
			assertTrue( artifactIsCached( "org.example", "gone", "3.0.0" ), "the resolved artifact must be cached" );

			// The JAR is no longer published (metadata still lists the version).
			fileDelete( repo.dir & "/org/example/gone/3.0.0/gone-3.0.0.jar" );

			var message = catchThrown( function() {
				resolvePackage( "maven:#repo.url#|org.example:gone:3.0.x", "", verbose );
			} );

			assertEquals(
				"",
				message,
				"documented behavior: the cached JAR must be reused when the repo no longer serves it, but resolution failed with [#message#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "When the endpoint ID omits `repo`, CommandBox walks the list of registered repos in order
	 * and uses the first one that returns the artifact. A `404` (or any lookup failure) on one repo
	 * just moves us to the next."
	 *
	 * FAILS: for an exact version `getArtifactFromRepo()` builds the JAR URL without checking that it
	 * exists, so the first registered repo always wins and the install dies on the 404.
	 *
	 * @test
	 */
	function exactVersionFallsThroughToNextRegisteredRepo( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			publishArtifact( repo, "org.example", "fallthrough", "1.0.0", pom( groupId="org.example", artifactId="fallthrough", version="1.0.0" ) );
			clearArtifactCache( "org.example", "fallthrough", "1.0.0" );

			var projectPath = scratchDirectory( "fallthrough-project" );
			writeProjectDescriptor( projectPath, {
				"name"    : "maven-fallthrough",
				"version" : "1.0.0",
				"maven"   : {
					"repositories" : {
						// The repo that is consulted first has nothing for this GAV (404) - the resolver
						// must move on to the next registered repo.
						"mavenCentral" : "#repo.url#does-not-exist/",
						"realRepo"     : "#repo.url#"
					}
				}
			} );

			var message = catchThrown( function() {
				resolvePackage( "maven:org.example:fallthrough:1.0.0", projectPath, verbose );
			} );

			assertEquals(
				"",
				message,
				"documented behavior: a 404 in the first registered repo must fall through to the next, but resolution failed with [#message#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	/**
	 * Doc: "A `404` (or any lookup failure) on one repo just moves us to the next" — and the repo
	 * section's own verification note: "pointing `mavenCentral` at a bogus URL in a project `box.json`
	 * ... then correctly fell through to the next registered repo after it failed."
	 *
	 * FAILS: only `endpointException` is caught while walking repos, so an unreachable repo aborts
	 * resolution instead of falling through.
	 *
	 * @test
	 */
	function unreachableRepoFallsThroughToNextRepo( boolean verbose=false ) {
		var repo = startLocalRepo();
		try {
			// Serve from a nested path; the reachable alias below points at this throw-away server.
			publishArtifact( repo, "org.example", "unreachable", "1.0.0", pom( groupId="org.example", artifactId="unreachable", version="1.0.0" ) );
			clearArtifactCache( "org.example", "unreachable", "1.0.0" );

			var projectPath = scratchDirectory( "unreachable-project" );
			writeProjectDescriptor( projectPath, {
				"name"    : "maven-unreachable",
				"version" : "1.0.0",
				"maven"   : {
					"repositories" : {
						// Connection refused - a lookup failure that should not be fatal.  Overriding
						// mavenCentral puts it first in the walk order.
						"mavenCentral" : "http://127.0.0.1:1/maven2/",
						"realRepo"     : "#repo.url#"
					}
				}
			} );

			var message = catchThrown( function() {
				resolvePackage( "maven:org.example:unreachable:1.0.0", projectPath, verbose );
			} );

			assertEquals(
				"",
				message,
				"documented behavior: an unreachable repo must fall through to the next registered repo, but resolution failed with [#message#]"
			);
		} finally {
			stopLocalRepo( repo );
		}
	}

	// ==============================================================================================
	// Helpers
	// ==============================================================================================

	/**
	 * Resolves a `maven:` endpoint ID through the endpoint itself and returns the generated package
	 * directory plus its parsed box.json.
	 */
	private struct function resolvePackage( required string packageId, string workingDirectory="", boolean verbose=false ) {
		// The endpoint logs its progress through the interactive job, which requires an active job
		// when it isn't being run from inside a command.
		var job = getInstance( "interactiveJob" );
		job.start( "Resolving #arguments.packageId#", 1 );
		try {
			var packagePath = getInstance( "endpointService" )
				.getEndpoint( "maven" )
				.resolvePackage(
					package                 = arguments.packageId,
					currentWorkingDirectory = arguments.workingDirectory,
					verbose                 = arguments.verbose
				);
		} finally {
			job.complete( false );
		}

		return {
			"path"       : packagePath,
			"descriptor" : deserializeJSON( fileRead( packagePath & "/box.json" ) )
		};
	}

	/**
	 * Installs a package through the real `package install` flow, which also exercises PackageService.
	 */
	private void function installPackage( required string packageId, required string directory ) {
		command( "package install" )
			.params(
				ID        = arguments.packageId,
				directory = arguments.directory,
				save      = false,
				lock      = false
			)
			.run();
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

	/**
	 * Starts a throw-away Maven repository on 127.0.0.1 (ephemeral port) serving `scratch/http-repo/`,
	 * and truncates the request log.  Returns { server, url, dir }.
	 */
	private struct function startLocalRepo() {
		var baseDirectory = getDirectoryFromPath( getCurrentTemplatePath() ) & "scratch";
		var repoDirectory = baseDirectory & "/http-repo";
		if( directoryExists( repoDirectory ) ) {
			directoryDelete( repoDirectory, true );
		}
		directoryCreate( repoDirectory, true, true );
		fileWrite( baseDirectory & "/http-repo-requests.log", "" );

		var handler = createDynamicProxy( "RepoHttpHandler", [ "com.sun.net.httpserver.HttpHandler" ] );
		var httpServer = createObject( "java", "com.sun.net.httpserver.HttpServer" ).create(
			createObject( "java", "java.net.InetSocketAddress" ).init( "127.0.0.1", 0 ),
			0
		);
		httpServer.createContext( "/", handler );
		httpServer.start();

		return {
			"server" : httpServer,
			"url"    : "http://127.0.0.1:#httpServer.getAddress().getPort()#/",
			"dir"    : repoDirectory
		};
	}

	private void function stopLocalRepo( required struct localRepo ) {
		arguments.localRepo.server.stop( 0 );
	}

	/**
	 * Publishes `org.example:lib` at each supplied version.
	 */
	private void function publishLibraryVersions( required struct localRepo, required array versions ) {
		for( var version in arguments.versions ) {
			publishArtifact(
				arguments.localRepo,
				"org.example",
				"lib",
				version,
				pom( groupId="org.example", artifactId="lib", version=version )
			);
		}
	}

	/**
	 * Publishes `org.example:<artifactId>:1.0.0` depending on `org.example:lib` at the given version.
	 */
	private void function publishWantsLib(
		required struct localRepo,
		required string artifactId,
		required string libVersion
	) {
		publishArtifact(
			arguments.localRepo,
			"org.example",
			arguments.artifactId,
			"1.0.0",
			pom(
				groupId      = "org.example",
				artifactId   = arguments.artifactId,
				version      = "1.0.0",
				dependencies = dependency( "org.example", "lib", arguments.libVersion )
			)
		);
	}

	/**
	 * Writes a file into the running local repository, creating parent directories as needed.
	 */
	private void function writeRepoFile( required struct localRepo, required string relativePath, required any content ) {
		var filePath = arguments.localRepo.dir & "/" & arguments.relativePath;
		directoryCreate( getDirectoryFromPath( filePath ), true, true );
		fileWrite( filePath, arguments.content );
	}

	/**
	 * Publishes a GAV into the local repository: the JAR, a matching `.sha256` sidecar and the POM.
	 * Does NOT touch the artifact cache - tests that need a cache-cold resolve clear it themselves.
	 */
	private void function publishArtifact(
		required struct localRepo,
		required string groupId,
		required string artifactId,
		required string version,
		required string pomXML,
		any jarPayload="local-repo-demo-jar"
	) {
		var artifactPath = replace( arguments.groupId, ".", "/", "all" )
			& "/" & arguments.artifactId
			& "/" & arguments.version
			& "/" & arguments.artifactId & "-" & arguments.version;

		writeRepoFile( arguments.localRepo, artifactPath & ".pom", arguments.pomXML );
		writeRepoFile( arguments.localRepo, artifactPath & ".jar", arguments.jarPayload );
		writeRepoFile( arguments.localRepo, artifactPath & ".jar.sha256", sha256Of( arguments.jarPayload ) );
	}

	/**
	 * Publishes `org.example:demo:1.0.0` with the given POM and clears any cached copy so the resolve
	 * is cache-cold.
	 */
	private void function publishDemoArtifact(
		required struct localRepo,
		required string pomXML,
		any jarPayload="local-repo-demo-jar"
	) {
		publishArtifact( arguments.localRepo, "org.example", "demo", "1.0.0", arguments.pomXML, arguments.jarPayload );
		clearArtifactCache( "org.example", "demo", "1.0.0" );
	}

	/**
	 * Publishes a `maven-metadata.xml` for an artifact so STABLE/range resolution has something to read.
	 */
	private void function writeMavenMetadata(
		required struct localRepo,
		required string groupId,
		required string artifactId,
		required array versions
	) {
		var versionXML = arguments.versions.map( ( version ) => "<version>#version#</version>" ).toList( "" );
		var metadata = '<?xml version="1.0" encoding="UTF-8"?>
<metadata>
	<groupId>#arguments.groupId#</groupId>
	<artifactId>#arguments.artifactId#</artifactId>
	<versioning>
		<latest>#arguments.versions.last()#</latest>
		<release>#arguments.versions.last()#</release>
		<versions>#versionXML#</versions>
		<lastUpdated>20240101000000</lastUpdated>
	</versioning>
</metadata>';

		writeRepoFile(
			arguments.localRepo,
			replace( arguments.groupId, ".", "/", "all" ) & "/" & arguments.artifactId & "/maven-metadata.xml",
			metadata
		);
	}

	/**
	 * Every artifact-cache directory for a GA, regardless of the flag suffix the endpoint derived.
	 */
	private array function cacheDirectoriesFor( required string groupId, required string artifactId ) {
		var prefix = "maven-" & arguments.groupId & "--" & arguments.artifactId;
		var artifactsDirectory = getInstance( "artifactService" ).getArtifactsDirectory();
		var matches = [];

		for( var cacheDirectory in directoryList( artifactsDirectory, false, "array" ) ) {
			if( !directoryExists( cacheDirectory ) ) {
				continue;
			}
			var cacheName = cacheDirectory.replace( chr( 92 ), "/", "all" ).listLast( "/" );
			if( cacheName == prefix || ( cacheName.startsWith( prefix ) && cacheName.mid( prefix.len() + 1, 2 ) == "--" ) ) {
				matches.append( cacheDirectory );
			}
		}

		return matches;
	}

	/**
	 * Whether an exact GAV is present in CommandBox's artifact cache (any flag variant).
	 */
	private boolean function artifactIsCached( required string groupId, required string artifactId, required string version ) {
		for( var cacheDirectory in cacheDirectoriesFor( arguments.groupId, arguments.artifactId ) ) {
			if( directoryExists( cacheDirectory & "/" & arguments.version ) ) {
				return true;
			}
		}
		return false;
	}

	/**
	 * Reads the JAR bytes back out of an artifact-cache ZIP so a test can serve the identical payload
	 * from another repo.
	 */
	private binary function jarBytesFromCache( required string groupId, required string artifactId, required string version ) {
		var cacheKey = "maven-" & arguments.groupId & "--" & arguments.artifactId;
		var artifactPath = getInstance( "artifactService" ).getArtifactPath(
			packageName = cacheKey,
			version     = arguments.version,
			touch       = false
		);
		var zipFile = createObject( "java", "java.util.zip.ZipFile" ).init( artifactPath );
		try {
			var entries = zipFile.entries();
			while( entries.hasMoreElements() ) {
				var entry = entries.nextElement();
				if( entry.isDirectory() || !entry.getName().lCase().endsWith( ".jar" ) ) {
					continue;
				}
				return zipFile.getInputStream( entry ).readAllBytes();
			}
		} finally {
			zipFile.close();
		}

		error( "No JAR found in the artifact cache for [#arguments.groupId#:#arguments.artifactId#:#arguments.version#]" );
	}

	/**
	 * SHA-256 of a file's bytes.
	 */
	private string function fileHash( required string filePath ) {
		return hash( fileReadBinary( arguments.filePath ), "SHA-256" );
	}

	/**
	 * Returns the first JAR found in a resolved package directory.
	 */
	private string function jarInDirectory( required string directory ) {
		var jars = directoryExists( arguments.directory )
			? directoryList( arguments.directory, true, "array", "*.jar" )
			: [];
		return jars.len() ? jars.first() : "";
	}

	/**
	 * Captures a config setting (including whether it existed) so a test can restore it afterwards.
	 */
	private struct function captureConfigSetting( required string name ) {
		var sentinel = "setting-was-absent";
		var current = getInstance( "configService" ).getSetting( arguments.name, sentinel );
		if( current == sentinel ) {
			return { "exists" : false, "value" : "" };
		}
		return { "exists" : true, "value" : current };
	}

	/**
	 * Restores a setting captured by captureConfigSetting().
	 */
	private void function restoreConfigSetting( required string name, required struct captured ) {
		var configService = getInstance( "configService" );
		if( arguments.captured.exists ) {
			configService.setSetting( arguments.name, arguments.captured.value, false, true );
		} else {
			configService.removeSetting( arguments.name, true );
		}
	}

	/**
	 * Returns the lines the local repository has served so far (method + path per request).
	 */
	private array function servedRequests( required struct localRepo ) {
		var logPath = getDirectoryFromPath( getCurrentTemplatePath() ) & "scratch/http-repo-requests.log";
		if( !fileExists( logPath ) ) {
			return [];
		}
		return fileRead( logPath )
			.listToArray( chr( 10 ) )
			.filter( ( line ) => line.len() );
	}

	/**
	 * Hex SHA-256 of the given bytes, matching what a `.sha256` sidecar file contains.
	 */
	private string function sha256Of( required any bytes ) {
		return hash( arguments.bytes, "SHA-256" );
	}

	/**
	 * Wraps dependencies in a minimal-but-valid POM envelope.
	 */
	private string function pom(
		required string groupId,
		required string artifactId,
		required string version,
		string parent="",
		string properties="",
		string dependencyManagement="",
		string dependencies=""
	) {
		return '<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
	<modelVersion>4.0.0</modelVersion>
	#arguments.parent#
	<groupId>#arguments.groupId#</groupId>
	<artifactId>#arguments.artifactId#</artifactId>
	<version>#arguments.version#</version>
	#arguments.properties#
	#arguments.dependencyManagement#
	<dependencies>
		#arguments.dependencies#
	</dependencies>
</project>';
	}

	/**
	 * Builds one `<dependency>` entry, omitting empty parts.
	 */
	private string function dependency(
		required string groupId,
		required string artifactId,
		string version="",
		string scope="",
		string optional="",
		string exclusions=""
	) {
		return '<dependency>'
			& '<groupId>#arguments.groupId#</groupId>'
			& '<artifactId>#arguments.artifactId#</artifactId>'
			& ( arguments.version.len() ? '<version>#arguments.version#</version>' : '' )
			& ( arguments.scope.len() ? '<scope>#arguments.scope#</scope>' : '' )
			& ( arguments.optional.len() ? '<optional>#arguments.optional#</optional>' : '' )
			& arguments.exclusions
			& '</dependency>';
	}

	/**
	 * Removes a GAV from CommandBox's artifact cache so the next resolve must consult the repos.
	 *
	 * Resolution flags (`scopes`, `optional`, `exclude`, `transitive`, `classifier`) are baked into the
	 * cached descriptor, and a cache hit only rehydrates the install mode and directory.  Any test
	 * asserting flag semantics therefore has to start cache-cold.  The artifact is a cache entry, so
	 * removing it is safe — it is simply re-downloaded.
	 */
	private void function clearArtifactCache( required string groupId, required string artifactId, required string version ) {
		// The endpoint suffixes cache entries with a hash of the resolution flags, so clear every
		// variant for this GA rather than trying to reproduce its key derivation here.
		for( var cacheDirectory in cacheDirectoriesFor( arguments.groupId, arguments.artifactId ) ) {
			var versionDirectory = cacheDirectory & "/" & arguments.version;
			if( directoryExists( versionDirectory ) ) {
				directoryDelete( versionDirectory, true );
			}
		}
	}

	/**
	 * Writes a project box.json into a scratch project directory.
	 */
	private void function writeProjectDescriptor( required string projectPath, required struct descriptor ) {
		if( !arguments.descriptor.keyExists( "dependencies" ) ) {
			arguments.descriptor[ "dependencies" ] = {};
		}
		fileWrite( arguments.projectPath & "/box.json", serializeJSON( arguments.descriptor, true ) );
	}

	// ==============================================================================================
	// Assertions
	// ==============================================================================================

	private void function assertJarExists( required string directory, required string jarName ) {
		var separators = "/" & chr( 92 );
		var jars = directoryExists( arguments.directory )
			? directoryList( arguments.directory, true, "array", "*.jar" )
			: [];

		for( var jar in jars ) {
			if( listLast( jar, separators ) == arguments.jarName ) {
				return;
			}
		}

		error( "Expected a JAR named [#arguments.jarName#] under [#arguments.directory#]; found [#jars.toList( ", " )#]." );
	}

	private void function assertThrows( required any callback, required string message ) {
		if( !catchThrown( arguments.callback ).len() ) {
			error( arguments.message );
		}
	}

	/**
	 * Runs the callback and returns the thrown error message, or an empty string if nothing threw.
	 * Harness-level failures ("No active job") are rethrown so they can never be mistaken for the
	 * behavior under test.
	 */
	private string function catchThrown( required any callback ) {
		try {
			arguments.callback();
		} catch( any e ) {
			// Never accept a harness-level failure as proof that the behavior under test failed.
			if( e.message.findNoCase( "No active job" ) ) {
				rethrow;
			}
			return e.message;
		}

		return "";
	}

	private void function assertTrue( required boolean condition, required string message ) {
		if( !arguments.condition ) {
			error( arguments.message );
		}
	}

	private void function assertFalse( required boolean condition, required string message ) {
		if( arguments.condition ) {
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

}
