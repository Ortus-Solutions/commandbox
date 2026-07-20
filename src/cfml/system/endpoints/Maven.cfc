/**
 *********************************************************************************
 * Copyright Since 2014 CommandBox by Ortus Solutions, Corp
 * www.coldbox.org | www.ortussolutions.com
 ********************************************************************************
 * @author Brad Wood, Luis Majano, Denny Valliant
 *
 * I am the maven endpoint. I get artifacts from the maven repository
 */
component
	accessors ="true"
	implements="IEndpoint"
	singleton
{

	// DI
	property name="jarEndpoint"     inject="commandbox.system.endpoints.Jar";
	property name="fileEndpoint"    inject="commandbox.system.endpoints.File";
	property name="artifactService" inject="ArtifactService";
	property name="semanticVersion" inject="provider:semanticVersion@semver";
	property name="JSONService"     inject="JSONService";
	property name="configService"   inject="configService";
	property name="wirebox"         inject="wirebox";
	property name="fileSystemUtil"  inject="FileSystem";
	property name="tempDir"         inject="tempDir@constants";
	property name="packageService"  inject="packageService";

	// Properties
	property name="namePrefixes"    type="string";
	property name="defaultRepo"     type="struct";
	property name="registeredRepos" type="struct";

	// Constructor
	/**
	 * Initializes the Maven endpoint defaults.
	 */
	function init(){
		setNamePrefixes( "maven" );
		setDefaultRepo( { "mavenCentral" : "https://maven-central.storage.googleapis.com/maven2/" } );
		return this;
	}

	/**
	 * Resolves the Maven package based on the provided package string.
	 * Handles different URL patterns for Maven repositories.
	 * @package The package to resolve
	 * @currentWorkingDirectory The directory to resolve the package in
	 * @verbose Verbose flag or silent, defaults to false
	 */
	public string function resolvePackage(
		required string package,
		string currentWorkingDirectory = "",
		boolean verbose                = false
	){
		var job = wirebox.getInstance( "interactiveJob" );
		var projectMaven = packageService.readPackageDescriptor( currentWorkingDirectory ).maven;
		var artifactParts = getArtifactParts( package );
		artifactParts.flags.installMode = resolveInstallMode( artifactParts.flags.installMode, projectMaven.installMode ?: "" );
		var installDirectory = resolveInstallDirectory( projectMaven.installDirectory ?: "" );

		// Build the registered repo list by layering three sources, with later sources overwriting
		// earlier ones on key collision (a project box.json can redefine a global alias, and a global
		// alias can redefine a built-in default).
		//   1. Built-in defaults (getDefaultRepo() — just mavenCentral).
		//   2. Global config: endpoints.maven.repositories.
		//   3. Project box.json: maven.repositories.
		variables.registeredRepos = duplicate( getDefaultRepo() );
		structAppend(
			variables.registeredRepos,
			variables.configService.getSetting( "endpoints.maven.repositories", {} ),
			true
		);
		structAppend(
			variables.registeredRepos,
			getProjectRepos( projectMaven ),
			true
		);

		var artifact = {
			"parts"           : artifactParts,
			"jarFileURL"      : "",
			"metadata"        : {},
			"resolvedVersion" : ""
		};

		// The parsed repo intent from the endpoint ID.  Empty means "check all registered repos".
		// Non-empty means "the user asked for this specific repo — use only it".
		var requestedRepo = artifact.parts.repo;

		job.addLog( "Checking the Maven artifact cache." );

		// If the local artifact exists AND we have an exact version, serve it from cache.
		// Exact versions are immutable in Maven, so a cache hit is safe.  STABLE and version ranges
		// must consult the remote metadata to know which concrete version to resolve to.
		// Note: we use isExactVersion() without includeBuildID so "2.0.0" (no build metadata) counts as exact.
		// Cache key is namespaced by endpoint ("maven-") plus groupId:artifactId ONLY — matching real
		// Maven/Gradle local repo semantics.  A given GAV (groupId:artifactId:version) is defined by
		// Maven Central's publishing rules to be immutable and identical no matter which repo serves it,
		// so which repo happened to resolve it is irrelevant to the cache.  This also means once an
		// artifact is cached from a trusted repo, a later untrusted/rogue repo entry can't shadow it.
		// The "maven-" prefix keeps our keys from colliding with other endpoints (ForgeBox, GitHub, etc.)
		// that share the same artifact cache.
		var cacheKey = "maven-" & artifact.parts.groupId & "--" & artifact.parts.artifactId
			& ( artifact.parts.flags.classifier.len() ? "--" & artifact.parts.flags.classifier : "" );
		if (
			artifact.parts.version != "STABLE"
			&& isExactMavenVersion( artifact.parts.version )
			&& artifactService.artifactExists( cacheKey, artifact.parts.version )
		) {
			job.addLog( "Using the Maven artifact already stored in the local artifact cache." );
			var thisArtifactPath = prepareCachedPackageForInstall(
				artifactService.getArtifactPath( cacheKey, artifact.parts.version ),
				artifact.parts.flags.installMode,
				installDirectory
			);
			if ( configService.getSetting( "offlineMode", false ) ) {
				job.addWarnLog( "Offline mode is enabled; skipping Maven JAR hash validation." );
			} else {
				verifyArtifactChecksum(
					findJarInPackage( thisArtifactPath ),
					getJarFileURL(
						requestedRepo.len() ? requestedRepo : "mavenCentral",
						artifact.parts.groupId,
						artifact.parts.artifactId,
						artifact.parts.version,
						artifact.parts.flags.classifier
					)
				);
			}

			// Return the rehydrated package directory directly.
			return thisArtifactPath;
		}

		// If the user explicitly requested a repo, use ONLY that one.  Otherwise walk the registered
		// repos in order (project box.json overrides same-named global config entries) and use the
		// first one that has the artifact.
		// Track which repo actually served the artifact so subsequent HTTP calls (POM, dep metadata)
		// go to the same one.
		var resolvedRepo = "";
		if ( requestedRepo.len() ) {
			job.addLog( "Trying repo [#requestedRepo#]" );
			var returnedArtifact = getArtifactFromRepo(
				requestedRepo,
				artifact.parts.groupId,
				artifact.parts.artifactId,
				artifact.parts.version,
				artifact.parts.flags.snapshots,
				artifact.parts.flags.classifier
			);
			artifact.metadata        = returnedArtifact.metadata;
			artifact.jarFileURL      = returnedArtifact.jarFileURL;
			artifact.resolvedVersion = returnedArtifact.resolvedVersion;
			resolvedRepo             = requestedRepo;
			job.addLog( "Resolved from repo [#requestedRepo#]" );
		} else {
			for ( var alias in getRegisteredRepos() ) {
				job.addLog( "Trying repo [#alias#]" );
				try {
					var returnedArtifact = getArtifactFromRepo(
						alias,
						artifact.parts.groupId,
						artifact.parts.artifactId,
						artifact.parts.version,
						artifact.parts.flags.snapshots,
						artifact.parts.flags.classifier
					);
				} catch ( endpointException e ) {
					// Artifact not found in this repo (404 / metadata missing / range not satisfied) —
					// try the next registered repo.  Only endpointExceptions are treated as fallback signals.
					job.addLog( "  Not found in [#alias#]: #e.message#" );
					continue;
				}
				if ( returnedArtifact.jarFileURL.len() ) {
					artifact.metadata        = returnedArtifact.metadata;
					artifact.jarFileURL      = returnedArtifact.jarFileURL;
					artifact.resolvedVersion = returnedArtifact.resolvedVersion;
					resolvedRepo             = alias;
					job.addLog( "  Resolved from repo [#alias#]" );
					break;
				}
				job.addLog( "  Not found in [#alias#]" );
			}
			if ( !artifact.jarFileURL.len() ) {
				throw(
					message = "Could not find Maven artifact [#artifact.parts.groupId#:#artifact.parts.artifactId#:#artifact.parts.version#] in any registered repo.",
					type    = "endpointException"
				);
			}
		}

		// Before hitting the network, check the user's local Maven repository (~/.m2/repository).
		// We never write anything there — it's purely an additional, already-populated local source
		// worth checking, since most machines with any other JVM tooling (IDEs, Maven, Gradle, etc.)
		// already have it full of artifacts.  Only usable once we know the exact concrete version
		// (getArtifactFromRepo always resolves STABLE/ranges to a concrete version before returning).
		var localM2JarPath = getLocalM2JarPath(
			artifact.parts.groupId,
			artifact.parts.artifactId,
			artifact.resolvedVersion,
			artifact.parts.flags.classifier
		);

		var folderName = "";
		if ( localM2JarPath.len() ) {
			job.addLog( "Found in local Maven repository cache (~/.m2/repository) - skipping download: #localM2JarPath#" );
			if ( !configService.getSetting( "offlineMode", false ) ) {
				verifyArtifactChecksum( localM2JarPath, artifact.jarFileURL );
			}
			folderName = buildPackageFromLocalJar(
				localM2JarPath,
				artifact.parts.artifactId,
				artifact.resolvedVersion,
				artifact.parts.flags.classifier
			);
		} else {
			// Defer to jar endpoint
			folderName = jarEndpoint.resolvePackage(
				artifact.jarFileURL,
				currentWorkingDirectory,
				arguments.verbose
			);
			if ( !configService.getSetting( "offlineMode", false ) ) {
				verifyArtifactChecksum( findJarInPackage( folderName ), artifact.jarFileURL );
			}
		}

		if ( artifact.parts.version eq "STABLE" ) {
			artifact.parts.version = getLatestVersion(
				resolvedRepo,
				artifact.parts.groupId,
				artifact.parts.artifactId,
				artifact.parts.flags.snapshots
			);
		}

		// Update artifact version if it's a range
		else if ( !isExactMavenVersion( artifact.parts.version ) ) {
			job.addLog( "Resolving Maven version range [#artifact.parts.version#]." );
			if (
				artifact.metadata.keyExists( "versioning" ) && artifact.metadata.versioning.keyExists( "versions" ) && artifact.metadata.versioning.versions.len()
			) {
				// Exclude SNAPSHOT versions from range resolution by default — a range like ">=1.0 <2.0"
				// should pick a stable release.  Caller can opt in with snapshots=true.
				var sortedVersions = artifact.metadata.versioning.versions
					.filter( ( v ) => artifact.parts.flags.snapshots || !findNoCase( "SNAPSHOT", v ) )
					.sort( ( a, b ) => variables.semanticVersion.compare( b, a ) );
				// Get the latest version that matches the range
				for ( var thisVersion in sortedVersions ) {
					if ( semanticVersion.satisfies( thisVersion, artifact.parts.version ) ) {
						job.addLog( "Selected Maven version [#thisVersion#] for the requested range." );
						artifact.parts.version = thisVersion;
						break;
					}
				}
			}
		}

		job.addLog( "Using Maven version [#artifact.parts.version#]." );

		// After resolving STABLE/range to a concrete version, check the cache again before
		// downloading and reprocessing dependencies.  This is the common case for repeat installs.
		if (
			isExactMavenVersion( artifact.parts.version )
			&& artifactService.artifactExists( cacheKey, artifact.parts.version )
		) {
			job.addLog( "Resolved version [#artifact.parts.version#] already in local artifacts, using cache." );
			var thisArtifactPath = prepareCachedPackageForInstall(
				artifactService.getArtifactPath( cacheKey, artifact.parts.version ),
				artifact.parts.flags.installMode,
				installDirectory
			);
			verifyArtifactChecksum( findJarInPackage( thisArtifactPath ), artifact.jarFileURL );
			return thisArtifactPath;
		}

		// Get dependencies — use the repo that actually served the parent artifact.  If the user
		// disabled transitives via `?transitive=false`, skip dep resolution entirely.
		var artifactDependencies = artifact.parts.flags.transitive
			? getArtifactAndDependencyJarURLs(
				resolvedRepo,
				artifact.parts.groupId,
				artifact.parts.artifactId,
				artifact.parts.version,
				artifact.parts.flags.scopes,
				0,
				artifact.parts.flags.optional,
				artifact.parts.flags.exclude
			)
			: [];

		var installPaths = {};
		var dependencies = {};

		for ( var dependency in artifactDependencies ) {
			if ( dependency.artifactId == artifact.parts.artifactId && dependency.groupId == artifact.parts.groupId ) {
				continue;
			}
			// Use the same slug format as the generated package descriptor. PackageService uses the
			// descriptor slug as the dependency key when saving the installed package, so using a
			// different key here would cause a second entry to be added for the same dependency.
			var depKey = dependency.groupId & ":" & dependency.artifactId;
			// Merge the exclude set that should apply to THIS child's own subtree:
			//   - Whatever the user/parent already had in effect (`?exclude=` on this artifact's own
			//     endpoint ID) — propagated uniformly to every child so it keeps applying deeper down.
			//   - Whatever THIS specific POM declared via <exclusions> for THIS dependency edge —
			//     applies only to this one child's subtree, not its siblings.
			var childExcludes = mergeExcludeLists( artifact.parts.flags.exclude, dependency.exclusions );
			// Build a proper maven: endpoint ID for the dependency.  Do NOT force the parent's repo alias
			// onto children — leave it repo-less so the child can be resolved from any registered repo
			// (or the artifact cache) independently.  If the user needs pinned repo behavior for a
			// transitive, they can register or override via the project box.json.
			dependencies[ depKey ] = getNamePrefixes() & ":" & dependency.groupId & ":" & dependency.artifactId & ":" & convertMavenToNpmVersionRange(
				dependency.version
			);
			if ( childExcludes.len() ) {
				dependencies[ depKey ] &= "?exclude=" & childExcludes;
			}
			if ( artifact.parts.flags.installMode.len() ) {
				dependencies[ depKey ] &= ( find( "?", dependencies[ depKey ] ) ? "&" : "?" ) & "installMode=" & artifact.parts.flags.installMode;
			}
			// Shared installs bundle all Maven JARs into the caller's destination. Dedicated installs
			// keep each transitive dependency isolated directly under the parent package directory.
			installPaths[ depKey ] = artifact.parts.flags.installMode == "shared"
				? "."
				: dependency.groupId & "-" & dependency.artifactId;
		}

		// Override the box.json with the actual version and dependencies
		var boxJSON = {
			"name"         : "#artifact.parts.groupId & ":" & artifact.parts.artifactId#.jar",
			"slug"         : artifact.parts.groupId & ":" & artifact.parts.artifactId,
			"packageDirectory" : artifact.parts.groupId & "-" & artifact.parts.artifactId,
			"version"      : artifact.parts.version,
			"location"     : getNamePrefixes() & ":" & arguments.package,
			"type"         : "jars",
			"directory"    : installDirectory,
			"createPackageDirectory" : artifact.parts.flags.installMode != "shared",
			"installPathIsPackageDirectory" : artifact.parts.flags.installMode != "shared",
			"ignore"       : artifact.parts.flags.installMode == "shared" ? [ "/box.json" ] : [],
			"persistDependencies" : artifact.parts.flags.installMode != "shared",
			"maven"        : { "installMode" : artifact.parts.flags.installMode },
			"dependencies" : dependencies,
			"installPaths" : installPaths
		};

		JSONService.writeJSONFile( folderName & "/box.json", boxJSON );

		if ( !artifactService.artifactExists( cacheKey, artifact.parts.version ) ) {
			job.addLog( "Caching Maven artifact for future installs." );
			var cacheFolder = tempDir & "/maven-cache-" & createUUID();
			directoryCopy( folderName, cacheFolder, true );
			writeCachePackageDescriptor( cacheFolder );

			// Store it locally in the artifact cache using the same separator format as the lookup above.
			artifactService.createArtifact(
				cacheKey,
				artifact.parts.version,
				cacheFolder
			);

		}

		// Here is where our alleged so-called "package" lives.
		return folderName;
	}

	/**
	 * Get the default name of a package
	 * @package The package to get the default name for
	 */
	public function getDefaultName( required string package ){
		var packageParts = getArtifactParts( package );

		if ( packageParts.artifactId.len() ) {
			return packageParts.artifactId;
		}

		return reReplaceNoCase(
			arguments.package,
			"[^a-zA-Z0-9]",
			"",
			"all"
		);
	}

	/**
	 * Get the project repositories from the box.json file
	 * @currentWorkingDirectory The directory to get the repositories from
	 */
	function getProjectRepos( required struct projectMaven ){
		return arguments.projectMaven.keyExists( "repositories" ) ? arguments.projectMaven.repositories : {};
	}

	/**
	 * Checks if an artifact exists in the given repository and gets it
	 * @repo The repository to check (URL or alias)
	 * @groupId The group ID of the artifact
	 * @artifactId The artifact ID
	 * @version The version of the artifact
	 */
	private struct function getArtifactFromRepo(
		string repo,
		string groupId,
		string artifactId,
		string version,
		boolean allowSnapshots = false,
		string classifier = ""
	){
		var artifact = { "jarFileURL" : "", "metadata" : {}, "resolvedVersion" : "" }

		// Fast path: for an exact version we don't need to fetch metadata — the URL is fully deterministic.
		// STABLE and version ranges require metadata to know which concrete version to pick.
		if ( arguments.version != "STABLE" && isExactMavenVersion( arguments.version ) ) {
			artifact.jarFileURL = getJarFileURL(
				arguments.repo,
				arguments.groupId,
				arguments.artifactId,
				arguments.version,
				arguments.classifier
			);
			artifact.resolvedVersion = arguments.version;
			return artifact;
		}

		// get artifact metadata to make sure it exists
		try {
			var artifact.metadata = getArtifactMetadataFromMaven(
				arguments.repo,
				arguments.groupId,
				arguments.artifactId
			);
		} catch ( Any e ) {
			throw(
				message = "Could not find artifact metadata for [#arguments.groupId#:#arguments.artifactId#] in #arguments.repo# repository.  #e.message#",
				type    = "endpointException",
				detail  = e.detail,
				object = e
			);
		}

		// Get latest version if not specified
		if ( arguments.version eq "STABLE" ) {
			latestVersion = getLatestVersion(
				arguments.repo,
				arguments.groupId,
				arguments.artifactId,
				arguments.allowSnapshots
			);
			artifact.jarFileURL = getJarFileURL(
				arguments.repo,
				arguments.groupId,
				arguments.artifactId,
				latestVersion,
				arguments.classifier
			);
			artifact.resolvedVersion = latestVersion;
			return artifact;
		}

		// Version is a range — pick the highest matching from metadata.
		if (
			artifact.metadata.keyExists( "versioning" ) && artifact.metadata.versioning.keyExists( "versions" ) && artifact.metadata.versioning.versions.len()
		) {
			// Exclude SNAPSHOT versions from range resolution by default — opt in with allowSnapshots.
			// Captured into a local var because closures passed to .filter()/.sort() get their OWN
			// "arguments" scope — arguments.allowSnapshots is not visible inside the closure.
			var allowSnapshotsLocal = arguments.allowSnapshots;
			var sortedVersions = artifact.metadata.versioning.versions
				.filter( ( v ) => allowSnapshotsLocal || !findNoCase( "SNAPSHOT", v ) )
				.sort( ( a, b ) => variables.semanticVersion.compare( b, a ) );
			for ( var thisVersion in sortedVersions ) {
				if ( semanticVersion.satisfies( thisVersion, arguments.version ) ) {
					artifact.jarFileURL = getJarFileURL(
						arguments.repo,
						arguments.groupId,
						arguments.artifactId,
						thisVersion,
						arguments.classifier
					);
					artifact.resolvedVersion = thisVersion;
					return artifact;
				}
			}
			throw( message = "Could not find a version that satisfies the range: #arguments.version#", type = "endpointException" );
		}
		throw( message = "Could not find versions in artifact metadata", type = "endpointException" );
	}

	/**
	 * Get an update for a package
	 * @package The package name
	 * @version The package version
	 * @verbose Verbose flag or silent, defaults to false
	 *
	 * @return struct { isOutdated, version }
	 */
	public function getUpdate(
		required string package,
		required string version,
		boolean verbose = false
	){
		return {
			isOutdated : false,
			version    : "unknown"
		};
	}

	/**
	 * Get the latest stable version of an artifact from a repo's maven-metadata.xml.
	 *
	 * Prefers <versioning><release> (Maven's convention for "latest non-snapshot").  Falls back to
	 * scanning <versioning><versions> and picking the highest entry that isn't a SNAPSHOT.
	 *
	 * @repo The repository to check (URL or alias)
	 * @groupId The group ID of the artifact
	 * @artifactId The artifact ID
	 */
	private function getLatestVersion(
		string repo,
		string groupId,
		string artifactId,
		boolean allowSnapshots = false
	){
		var metadata = getArtifactMetadataFromMaven(
			arguments.repo,
			arguments.groupId,
			arguments.artifactId
		);

		if ( !metadata.keyExists( "versioning" ) ) {
			throw( message = "No <versioning> element in maven-metadata.xml for [#arguments.groupId#:#arguments.artifactId#]", type = "endpointException" );
		}

		// If the caller allows snapshots and metadata has a <latest> pointer, prefer that — <latest> is
		// Maven's designation for the newest published version regardless of stability.
		if ( arguments.allowSnapshots && metadata.versioning.keyExists( "latest" ) && len( metadata.versioning.latest ) ) {
			return metadata.versioning.latest;
		}

		// Prefer <release>: Maven's own designation for the latest non-snapshot version.
		if ( metadata.versioning.keyExists( "release" ) && len( metadata.versioning.release ) ) {
			return metadata.versioning.release;
		}

		// Fallback: pick the highest version from <versions>, filtering snapshots unless opted in.
		if ( metadata.versioning.keyExists( "versions" ) && arrayLen( metadata.versioning.versions ) ) {
			// Captured into a local var because closures passed to .filter()/.sort() get their OWN
			// "arguments" scope — arguments.allowSnapshots is not visible inside the closure.
			var allowSnapshotsLocal = arguments.allowSnapshots;
			var sortedVersions = metadata.versioning.versions
				.filter( ( v ) => allowSnapshotsLocal || !findNoCase( "SNAPSHOT", v ) )
				.sort( ( a, b ) => variables.semanticVersion.compare( b, a ) );
			if ( arrayLen( sortedVersions ) ) {
				return sortedVersions[ 1 ];
			}
		}

		throw( message = "Could not determine a stable version for [#arguments.groupId#:#arguments.artifactId#]", type = "endpointException" );
	}

	/**
	 * Parse a Maven endpoint ID into its parts.
	 *
	 * Format:
	 *   maven:[repo|]groupId:artifactId[:version][|flag=value&flag=value]
	 *
	 * Where repo is optional and may be:
	 *   - a registered alias:    sonatype
	 *   - a full URL:            https://repo.example.com/maven2/
	 *
	 * When a repo is given, ONLY that repo is consulted — the user asked for it specifically.
	 * When no repo is given, all registered repos are tried in order until one contains the
	 * artifact (project box.json repos override same-named global config repos).
	 *
	 * Recognized flags (all optional):
	 *   scopes     Comma-separated list of Maven scopes to include (default: runtime,compile).
	 *   snapshots  Allow SNAPSHOT versions when resolving STABLE / ranges (default: false).
	 *   optional   Include <optional>true</optional> transitive dependencies (default: false).
	 *   transitive Resolve and install transitive dependencies (default: true).
	 *
	 * Flags follow a `?` after the version, query-string style — same idea as a URL query string:
	 *   install "maven:foo:bar:1.0?snapshots=true"
	 *   install "maven:foo:bar:1.0?snapshots=true&transitive=false"
	 *   install "maven:sonatype|foo:bar:1.0?snapshots=true"
	 *
	 * Note: a bare `?` token by itself is reserved by the CommandBox shell as a help shortcut, but
	 * that only applies when `?` is the *entire* final token of a command.  Since `?` here is always
	 * embedded inside a larger quoted string, it is never treated as a help token.
	 *
	 * @package The package string (with or without the "maven:" prefix)
	 */
	private function getArtifactParts( string package ){
		var response = {
			"repo"       : "",
			"groupId"    : "",
			"artifactId" : "",
			"version"    : "",
			"flags"      : {
				"scopes"     : "runtime,compile",
				"snapshots"  : false,
				"optional"   : false,
				"transitive" : true,
				"exclude"    : "",
				"installMode": "",
				"classifier" : ""
			}
		};

		// Remove the 'maven:' prefix from the package
		var packageId = replace(
			arguments.package,
			"maven:",
			"",
			"one"
		);

		// Split off the flags first — everything after the first `?` (query-string style).  This is
		// unambiguous, so we do it before touching the repo/coordinates part at all.
		var coordsAndRepo = packageId;
		var flagString    = "";
		var qMark         = find( "?", packageId );
		if ( qMark ) {
			coordsAndRepo = left( packageId, qMark - 1 );
			flagString    = mid( packageId, qMark + 1, len( packageId ) - qMark );
		}

		// Split the remainder on `|` to separate an optional repo from the package coordinates:
		//   [ packageCoordinates ]
		//   [ repo, packageCoordinates ]
		var parts = listToArray( coordsAndRepo, "|" );
		var coords = "";

		switch ( arrayLen( parts ) ) {
			case 1:
				coords = parts[ 1 ];
				break;
			case 2:
				response.repo = trim( parts[ 1 ] );
				coords        = parts[ 2 ];
				break;
			default:
				throw( message = "Invalid Maven package string: #packageId#. Too many `|` separators.", type = "endpointException" );
		}

		if ( flagString.len() ) {
			parseEndpointFlags( flagString, response.flags );
		}

		// Split the package coordinates into their components
		var packageParts = listToArray( coords, ":" );

		// Make sure we have at least the groupId and artifactId
		if ( arrayLen( packageParts ) < 2 ) {
			throw( message = "Invalid Maven package string: #coords#. Must contain at least one colon (:) such as groupId:artifactId:version", type = "endpointException" );
		}
		response.groupId    = packageParts[ 1 ];
		response.artifactId = packageParts[ 2 ];
		response.version    = packageParts[ 3 ] ?: "STABLE"; // Default to STABLE if not provided

		return response;
	}

	/**
	 * Parse the `key=value&key=value` flag portion of an endpoint ID.  Unknown flags are silently
	 * ignored so we can add new ones without breaking existing IDs.
	 *
	 * @flagString The raw flag string (no leading `?`).
	 * @flags The flags struct to mutate.  Populated with recognized keys only.
	 */
	private void function parseEndpointFlags( required string flagString, required struct flags ){
		for ( var pair in listToArray( arguments.flagString, "&" ) ) {
			var eqPos = find( "=", pair );
			if ( !eqPos ) {
				continue;
			}
			var key = lCase( trim( left( pair, eqPos - 1 ) ) );
			var val = trim( mid( pair, eqPos + 1, len( pair ) - eqPos ) );
			switch ( key ) {
				case "scopes":
					if ( val.len() ) {
						arguments.flags.scopes = val;
					}
					break;
				case "exclude":
					// Comma-separated list of "groupId:artifactId" pairs to exclude from this
					// artifact's transitive dependency resolution — no version, Maven exclusions
					// always apply regardless of version.
					arguments.flags.exclude = val;
					break;
				case "snapshots":
				case "optional":
				case "transitive":
					if ( isBoolean( val ) ) {
						arguments.flags[ key ] = !!val;
					}
					break;
				case "installmode":
					if ( listFindNoCase( "dedicated,shared", val ) ) {
						arguments.flags.installMode = lCase( val );
					}
					break;
				case "classifier":
					if ( reFindNoCase( "^[a-z0-9][a-z0-9._-]*$", val ) ) {
						arguments.flags.classifier = val;
					} else if ( val.len() ) {
						throw( message = "Invalid Maven classifier [#val#]. Classifiers may contain letters, numbers, dots, underscores, and hyphens.", type = "endpointException" );
					}
					break;
				// Unknown key — ignore (forward compatible).
			}
		}
	}

	/**
	 * Resolves the install mode from endpoint flags, project settings, and global configuration.
	 * @requestedMode The install mode requested by the endpoint ID.
	 * @projectMode The install mode configured in the current project's box.json.
	 */
	private string function resolveInstallMode( required string requestedMode, required string projectMode ) {
		if ( arguments.requestedMode.len() ) {
			return arguments.requestedMode;
		}

		if ( listFindNoCase( "dedicated,shared", arguments.projectMode ) ) {
			return lCase( arguments.projectMode );
		}

		var globalMode = configService.getSetting( "endpoints.maven.installMode", "dedicated" );
		return listFindNoCase( "dedicated,shared", globalMode ) ? lCase( globalMode ) : "dedicated";
	}

	/**
	 * Resolves the install directory from project settings or global configuration.
	 * @projectDirectory The install directory configured in the current project's box.json.
	 */
	private string function resolveInstallDirectory( required string projectDirectory ) {
		if ( arguments.projectDirectory.len() ) {
			return arguments.projectDirectory;
		}

		return configService.getSetting( "endpoints.maven.installDirectory", "" );
	}

	/**
	 * Get the metadata for an artifact from Maven Central
	 * @repo The repository to check (URL or alias)
	 * @groupId The group ID of the artifact
	 * @artifactId The artifact ID
	 */
	private function getArtifactMetadataFromMaven( repo, groupId, artifactId ){
		var repoURL    = getRepoURL( arguments.repo );
		var addr       = repoURL & replace( groupId, ".", "/", "ALL" ) & "/" & artifactId & "/";
		var httpResult = "";
		var metaData   = "";
		var md         = {
			"groupId"    : "",
			"artifactId" : "",
			"versioning" : {
				"latest"      : "",
				"release"     : "",
				"versions"    : [],
				"lastUpdated" : ""
			}
		};

		if ( configService.getSetting( "offlineMode", false ) ) {
			throw(
				message = "Can't download [#getNamePrefixes()#:#artifactId#], CommandBox is in offline mode.  Go online with [config set offlineMode=false].",
				type    = "endpointException"
			);
		}
		cfhttp(
			url           = "#addr#maven-metadata.xml",
			proxyServer   = "#configService.getSetting( "proxy.server", "" )#",
			proxyPort     = "#configService.getSetting( "proxy.port", 80 )#",
			proxyUser     = "#configService.getSetting( "proxy.user", "" )#",
			proxyPassword = "#configService.getSetting( "proxy.password", "" )#",
			method        = "get",
			redirect      = true,
			timeout       = 20,
			result        = "httpResult"
		);
		if ( httpResult.statusCode contains "200" ) {
			if ( isSafeXML( httpResult.fileContent ) ) {
				metaData      = xmlParse( httpResult.fileContent );
				md.groupId    = metaData.xmlRoot.groupId.XmlText;
				md.artifactId = metaData.xmlRoot.artifactId.XmlText;
				if ( structKeyExists( metaData.xmlRoot, "versioning" ) ) {
					if ( structKeyExists( metaData.xmlRoot.versioning, "latest" ) ) {
						md.versioning.latest = metaData.xmlRoot.versioning.latest.XmlText;
					}
					if ( structKeyExists( metaData.xmlRoot.versioning, "release" ) ) {
						md.versioning.release = metaData.xmlRoot.versioning.release.XmlText;
					}
					if ( structKeyExists( metaData.xmlRoot.versioning, "versions" ) ) {
						for ( local.version in metaData.xmlRoot.versioning.versions.XmlChildren ) {
							arrayAppend( md.versioning.versions, local.version.XmlText );
						}
					}
				}
			} else {
				throw( message = "Metadata XML Contained Potentially Unsafe Directives", type = "endpointException" );
			}
		} else {
			throw( message = "Repository Request to #addr# returned status: #httpResult.statusCode#", type = "endpointException" );
		}
		return md;
	}

	/**
	 * Get the URL type of a repo
	 * @repo The repository to check (URL or alias)
	 */
	function getRepoURL( required string repo ){
		// Check if the repo is a known alias
		if ( listFindNoCase( getRegisteredRepos().keyList(), arguments.repo ) ) {
			return getRegisteredRepos()[ "#arguments.repo#" ];
		}

		// Check if it's a valid URL (starting with http:// or https://)
		if ( reFindNoCase( "^(https?://)", arguments.repo ) ) {
			return arguments.repo;
		}

		// If it's neither an alias nor a valid URL, throw an error
		throw( message = "Invalid repository URL or alias: #arguments.repo#", type = "endpointException" );
	}

	/**
	 * Get the version of an artifact from Maven Central
	 * @repo The repository URL to check
	 * @groupId The group ID of the artifact
	 * @artifactId The artifact ID
	 * @version The version of the artifact
	 */
	private function getArtifactVersion( repo, groupId, artifactId, version ){
		var job        = wirebox.getInstance( "interactiveJob" );
		var addr       = repo & replace( groupId, ".", "/", "ALL" ) & "/" & artifactId & "/" & version & "/" & artifactId & "-" & version & ".pom";
		var httpResult = "";

		if ( configService.getSetting( "offlineMode", false ) ) {
			throw(
				message = "Can't download [#getNamePrefixes()#:#artifactId#], CommandBox is in offline mode.  Go online with [config set offlineMode=false].",
				type    = "endpointException"
			);
		}

		cfhttp(
			url           = "#addr#",
			proxyServer   = "#configService.getSetting( "proxy.server", "" )#",
			proxyPort     = "#configService.getSetting( "proxy.port", 80 )#",
			proxyUser     = "#configService.getSetting( "proxy.user", "" )#",
			proxyPassword = "#configService.getSetting( "proxy.password", "" )#",
			method        = "get",
			redirect      = true,
			timeout       = 20,
			result        = "httpResult"
		);
		if ( httpResult.statusCode contains "200" ) {
			return parsePOM( httpResult.fileContent, arguments.repo );
		} else {
			throw( message = "Repository Request to #addr# returned status: #httpResult.statusCode#", type = "endpointException" );
		}
	}

	/**
	 * Get the URLs for the artifact and its dependencies
	 * @repo The repository to check (URL or alias)
	 * @groupId The group ID of the artifact
	 * @artifactId The artifact ID
	 * @version The version of the artifact
	 * @scopes The scopes to include
	 * @depth The depth of the dependencies
	 */
	private function getArtifactAndDependencyJarURLs(
		repository,
		groupIdentifier,
		artifactIdentifier,
		versionNumber,
		scopes          = "runtime,compile",
		depthLevel      = 0,
		boolean includeOptional = false,
		string excludeList = ""
	){
		var job              = wirebox.getInstance( "interactiveJob" );
		var artifactMetadata = getArtifactVersion(
			getRepoURL( arguments.repository ),
			groupIdentifier,
			artifactIdentifier,
			versionNumber
		);
		var dependencyCache    = {};
		var jarDownloadList    = [];
		var dependency         = "";
		var dependencyMetadata = "";
		var selectedVersion    = "";

		if ( artifactMetadata.packaging IS "jar" ) {
			jarDownloadList = [
				{
					"download" : getJarFileURL(
						arguments.repository,
						groupIdentifier,
						artifactIdentifier,
						versionNumber
					),
					"groupId"    : arguments.groupIdentifier,
					"artifactId" : arguments.artifactIdentifier,
					"version"    : arguments.versionNumber,
					"exclusions" : []
				}
			];
		}

		for ( dependency in artifactMetadata.dependencies ) {
			// Skip scopes not being requested (default: runtime,compile).  This filters out test, provided, system.
			if ( !listFindNoCase( arguments.scopes, dependency.scope ) ) {
				continue;
			}
			// Skip optional dependencies unless the caller opted in.  Per Maven semantics they are not
			// transitive by default.  dependency.optional may be a real boolean or a "true"/"false" string from XML.
			if ( !arguments.includeOptional && isBoolean( dependency.optional ) && dependency.optional ) {
				continue;
			}
			// Skip anything the caller asked to exclude (via the ?exclude= flag, inherited uniformly
			// down the whole subtree) — "groupId:artifactId" pairs, no version.
			if ( arguments.excludeList.len() && listFindNoCase( arguments.excludeList, dependency.groupId & ":" & dependency.artifactId ) ) {
				continue;
			}
			// Must have a resolved version to be installable.  With <dependencyManagement> inheritance
			// working correctly, this should always be set — no need for a metadata HTTP fetch.
			if ( !len( dependency.version ) ) {
				continue;
			}
			var depKey = dependency.groupId & "/" & dependency.artifactId;
			if ( !dependencyCache.keyExists( depKey ) ) {
				dependencyCache[ depKey ] = {
					"groupId"       : dependency.groupId,
					"artifactId"    : dependency.artifactId,
					"scope"         : dependency.scope,
					"wantedVersion" : [ dependency.version ],
					// POM-native <exclusions> declared specifically on this dependency edge — only
					// applies to this dependency's own subtree, not its siblings.
					"exclusions"    : duplicate( dependency.exclusions )
				};
			} else {
				// Additional version seen for the same dep — record it so we can pick the highest later
				arrayAppend( dependencyCache[ depKey ].wantedVersion, dependency.version );
				for ( var excl in dependency.exclusions ) {
					if ( !arrayFindNoCase( dependencyCache[ depKey ].exclusions, excl ) ) {
						arrayAppend( dependencyCache[ depKey ].exclusions, excl );
					}
				}
			}
		}

		for ( dependency in dependencyCache ) {
			dependency = dependencyCache[ dependency ];
			// TODO: Pick the highest version when multiple are wanted
			selectedVersion = dependency.wantedVersion[ 1 ];
			if ( dependency.artifactId == arguments.artifactIdentifier && dependency.groupId == arguments.groupIdentifier ) {
				continue;
			}
			if ( artifactMetadata.packaging IS "pom" && dependency.scope IS "import" ) {
				if ( depthLevel > 10 ) {
					throw( message = "Maximum depth of 10 reached", type = "endpointException" );
				}
				dependencyMetadata = getArtifactAndDependencyJarURLs(
					repository,
					dependency.groupId,
					dependency.artifactId,
					selectedVersion,
					scopes,
					depthLevel++,
					arguments.includeOptional,
					arguments.excludeList
				);
				for ( selectedVersion in dependencyMetadata ) {
					if ( !arrayFind( jarDownloadList, selectedVersion ) ) {
						arrayAppend( jarDownloadList, selectedVersion );
					}
				}
			} else {
				arrayAppend(
					jarDownloadList,
					{
						"download" : getJarFileURL(
							repository,
							dependency.groupId,
							dependency.artifactId,
							selectedVersion
						),
						"groupId"    : dependency.groupId,
						"artifactId" : dependency.artifactId,
						"version"    : selectedVersion,
						"exclusions" : dependency.exclusions
					}
				);
			}
		}
		return jarDownloadList;
	}

	/**
	 * Get the URL for a JAR file
	 * @repo The repository to check (URL or alias)
	 * @groupId The group ID of the artifact
	 * @artifactId The artifact ID
	 * @version The version of the artifact
	 */
	private function getJarFileURL( repo, groupId, artifactId, version, string classifier = "" ){
		var classifierSuffix = arguments.classifier.len() ? "-" & arguments.classifier : "";
		var addr = getRepoURL( arguments.repo ) & replace( groupId, ".", "/", "ALL" ) & "/" & artifactId & "/" & version & "/" & artifactId & "-" & version & classifierSuffix & ".jar";
		return addr;
	}

	/**
	 * Copies or extracts a cached package and updates its descriptor for the requested installation.
	 * @cachedPackage The cached package directory or ZIP archive.
	 * @installMode The selected Maven installation mode.
	 * @installDirectory The destination directory configured for installation.
	 */
	private string function prepareCachedPackageForInstall(
		required string cachedPackage,
		required string installMode,
		required string installDirectory
	) {
		var installPackage = tempDir & "/maven-install-" & createUUID();
		if ( fileExists( arguments.cachedPackage ) && arguments.cachedPackage.endsWith( ".zip" ) ) {
			extractCachedPackage( arguments.cachedPackage, installPackage );
		} else {
			directoryCopy( arguments.cachedPackage, installPackage, true );
		}
		var descriptorPath = installPackage & "/box.json";
		var descriptor = deserializeJSON( fileRead( descriptorPath ) );
		descriptor.createPackageDirectory = arguments.installMode != "shared";
		descriptor.packageDirectory = replace( descriptor.slug, ":", "-", "all" );
		descriptor.directory = arguments.installDirectory;
		descriptor.installPathIsPackageDirectory = arguments.installMode != "shared";
		descriptor.ignore = arguments.installMode == "shared" ? [ "/box.json" ] : [];
		descriptor.persistDependencies = arguments.installMode != "shared";
		descriptor.maven = { "installMode" : arguments.installMode };
		for ( var dependency in descriptor.dependencies ) {
			descriptor.dependencies[ dependency ] = setInstallModeFlag(
				descriptor.dependencies[ dependency ],
				arguments.installMode
			);
			descriptor.installPaths[ dependency ] = arguments.installMode == "shared"
				? "."
				: replace( dependency, ":", "-", "all" );
		}
		JSONService.writeJSONFile( descriptorPath, descriptor );
		return installPackage;
	}

	/**
	 * Replaces the installMode flag on a Maven package endpoint ID.
	 * @packageID The Maven package endpoint ID.
	 * @installMode The install mode to include in the endpoint ID.
	 */
	private string function setInstallModeFlag( required string packageID, required string installMode ) {
		var queryStart = find( "?", arguments.packageID );
		var packageCoordinates = queryStart
			? left( arguments.packageID, queryStart - 1 )
			: arguments.packageID;
		var flags = queryStart
			? listToArray( mid( arguments.packageID, queryStart + 1, len( arguments.packageID ) - queryStart ), "&" )
			: [];
		var updatedFlags = [];

		for ( var flag in flags ) {
			if ( !flag.lCase().startsWith( "installmode=" ) ) {
				updatedFlags.append( flag );
			}
		}

		updatedFlags.append( "installMode=" & arguments.installMode );
		return packageCoordinates & "?" & updatedFlags.toList( "&" );
	}

	/**
	 * Extracts a cached ZIP package archive to a destination directory.
	 * @archivePath The ZIP archive to extract.
	 * @destination The directory where the archive contents are written.
	 */
	private void function extractCachedPackage( required string archivePath, required string destination ) {
		directoryCreate( arguments.destination );
		var zipFile = createObject( "java", "java.util.zip.ZipFile" ).init( arguments.archivePath );
		var entries = zipFile.entries();
		while ( entries.hasMoreElements() ) {
			var entry = entries.nextElement();
			var outputPath = arguments.destination & "/" & entry.getName();
			if ( entry.isDirectory() ) {
				directoryCreate( outputPath, true );
			} else {
				var parentPath = getDirectoryFromPath( outputPath );
				if ( !directoryExists( parentPath ) ) {
					directoryCreate( parentPath, true );
				}
				var inputStream = zipFile.getInputStream( entry );
				createObject( "java", "java.nio.file.Files" ).copy(
					inputStream,
					createObject( "java", "java.nio.file.Paths" ).get( outputPath ),
					[ createObject( "java", "java.nio.file.StandardCopyOption" ).REPLACE_EXISTING ]
				);
				inputStream.close();
			}
		}
		zipFile.close();
	}

	/**
	 * Updates a cached package descriptor with dedicated-install defaults.
	 * @cacheFolder The cached package directory containing box.json.
	 */
	private void function writeCachePackageDescriptor( required string cacheFolder ) {
		var descriptorPath = arguments.cacheFolder & "/box.json";
		var descriptor = deserializeJSON( fileRead( descriptorPath ) );
		descriptor.createPackageDirectory = true;
		descriptor.packageDirectory = replace( descriptor.slug, ":", "-", "all" );
		descriptor.directory = "";
		descriptor.installPathIsPackageDirectory = true;
		descriptor.ignore = [];
		descriptor.persistDependencies = true;
		descriptor.maven = { "installMode" : "dedicated" };
		JSONService.writeJSONFile( descriptorPath, descriptor );
	}

	/**
	 * Determines whether a Maven version identifies one immutable concrete artifact.
	 * @version The Maven version to evaluate.
	 */
	private boolean function isExactMavenVersion( required string version ) {
		return !reFindNoCase( "[\[\]\(\)\*xX~^<>= ]", arguments.version )
			&& reFindNoCase( "^[0-9]+(?:\.[0-9]+)*(?:[-+][0-9A-Za-z.-]+)?$", arguments.version );
	}

	/**
	 * Finds the first JAR in a package directory or cached ZIP archive.
	 * @packageDirectory The package directory or ZIP archive to inspect.
	 */
	private string function findJarInPackage( required string packageDirectory ) {
		var jars = directoryList( arguments.packageDirectory, false, "path", "*.jar" );
		if ( !jars.len() && fileExists( arguments.packageDirectory ) && arguments.packageDirectory.endsWith( ".zip" ) ) {
			var zipFile = createObject( "java", "java.util.zip.ZipFile" ).init( arguments.packageDirectory );
			var entries = zipFile.entries();
			while ( entries.hasMoreElements() ) {
				var entry = entries.nextElement();
				if ( !entry.isDirectory() && entry.getName().endsWith( ".jar" ) ) {
					var extractedJar = getTempDirectory() & "/maven-checksum-#createUUID()#.jar";
					var inputStream = zipFile.getInputStream( entry );
					var outputStream = createObject( "java", "java.nio.file.Files" ).newOutputStream(
						createObject( "java", "java.nio.file.Paths" ).get( extractedJar )
					);
					inputStream.transferTo( outputStream );
					inputStream.close();
					outputStream.close();
					zipFile.close();
					return extractedJar;
				}
			}
			zipFile.close();
		}
		if ( !jars.len() ) {
			throw( message = "Maven artifact package contains no JAR: #arguments.packageDirectory#", type = "endpointException" );
		}
		return jars[ 1 ];
	}

	/**
	 * Validates a JAR against the SHA-256 or SHA-1 checksum published by its Maven repository.
	 * @jarPath The local JAR file to validate.
	 * @jarURL The Maven repository URL for the JAR.
	 */
	private void function verifyArtifactChecksum( required string jarPath, required string jarURL ) {
		if ( configService.getSetting( "offlineMode", false ) ) {
			wirebox.getInstance( "interactiveJob" ).addWarnLog( "Offline mode is enabled; skipping Maven JAR hash validation for [#arguments.jarURL#]." );
			return;
		}

		var checksumResult = getRemoteChecksum( arguments.jarURL & ".sha256", "SHA-256" );
		var checksum = checksumResult.value;
		var algorithm = "SHA-256";
		if ( !checksum.len() ) {
			checksumResult = getRemoteChecksum( arguments.jarURL & ".sha1", "SHA-1" );
			checksum = checksumResult.value;
			algorithm = "SHA-1";
		}
		if ( !checksum.len() ) {
			if ( checksumResult.networkError ) {
				wirebox.getInstance( "interactiveJob" ).addWarnLog( "Unable to reach the Maven checksum service; skipping JAR hash validation for [#arguments.jarURL#]." );
				return;
			}
			throw( message = "Maven repository did not provide a SHA-256 or SHA-1 checksum for [#arguments.jarURL#]", type = "endpointException" );
		}
		wirebox.getInstance( "interactiveJob" ).addLog( "Verifying Maven JAR with #algorithm# checksum." );
		var actualChecksum = hash( fileReadBinary( arguments.jarPath ), algorithm );
		if ( compareNoCase( actualChecksum, checksum ) != 0 ) {
			throw( message = "Maven checksum mismatch for [#arguments.jarURL#]. Expected [#checksum#], received [#actualChecksum#].", type = "endpointException" );
		}
	}

	/**
	 * Retrieves and validates a remote Maven checksum file.
	 * @checksumURL The URL of the checksum file.
	 * @algorithm The checksum algorithm expected from the file.
	 */
	private struct function getRemoteChecksum( required string checksumURL, required string algorithm ) {
		var httpResult = "";
		try {
			cfhttp(
				url = arguments.checksumURL,
				method = "get",
				redirect = true,
				timeout = 20,
				result = "httpResult"
			);
		} catch ( any e ) {
			return { "value" : "", "networkError" : true };
		}
		if ( !httpResult.statusCode contains "200" ) {
			return { "value" : "", "networkError" : false };
		}
		var checksum = trim( listFirst( trim( httpResult.fileContent ), " " & chr( 9 ) ) );
		return {
			"value"       : reFindNoCase( "^[0-9a-f]{#algorithm == 'SHA-256' ? 64 : 40#}$", checksum ) ? checksum : "",
			"networkError": false
		};
	}

	/**
	 * Merge an inherited exclude list (comma-separated "groupId:artifactId" pairs, e.g. from a
	 * parent's `?exclude=` flag) with a set of POM-native exclusions declared on one specific
	 * dependency edge, returning a deduped comma-separated list ready to stamp onto a child's
	 * generated endpoint ID.
	 *
	 * @inherited Comma-separated "groupId:artifactId" list already in effect (may be empty).
	 * @edgeSpecific Array of "groupId:artifactId" strings declared via <exclusions> for this one edge.
	 */
	private string function mergeExcludeLists( required string inherited, required array edgeSpecific ){
		var merged = arguments.inherited.len() ? listToArray( arguments.inherited ) : [];
		for ( var excl in arguments.edgeSpecific ) {
			if ( !arrayFindNoCase( merged, excl ) ) {
				arrayAppend( merged, excl );
			}
		}
		return arrayToList( merged );
	}

	/**
	 * Look for an artifact's jar directly in the user's local Maven repository (~/.m2/repository),
	 * using the same layout Maven itself uses on disk.  We never write here — this is purely an
	 * additional, best-effort local source to check before hitting the network, since any machine
	 * that's done other JVM work (IDEs, Maven, Gradle via Maven-compat resolvers, etc.) likely
	 * already has it populated.  Only meaningful for an exact, concrete version — the local repo
	 * has no notion of "latest" or ranges.
	 *
	 * Any error (missing ~/.m2, permission issues, weird mounts, etc.) is swallowed and treated as
	 * "not found" — this check must never block or fail an install.
	 *
	 * @groupId The Maven groupId
	 * @artifactId The Maven artifactId
	 * @version The exact, concrete version to look for
	 * @return The absolute path to the local jar if found, or "" if not found (or any error occurred)
	 */
	private string function getLocalM2JarPath(
		required string groupId,
		required string artifactId,
		required string version,
		string classifier = ""
	){
		try {
			if ( !arguments.version.len() ) {
				return "";
			}
			var m2JarPath = fileSystemUtil.resolvePath( "~/.m2/repository" )
				& "/"
				& replace( arguments.groupId, ".", "/", "ALL" )
				& "/"
				& arguments.artifactId
				& "/"
				& arguments.version
				& "/"
				& arguments.artifactId
				& "-"
				& arguments.version
				& ( arguments.classifier.len() ? "-" & arguments.classifier : "" )
				& ".jar";
			if ( fileExists( m2JarPath ) ) {
				return m2JarPath;
			}
		} catch ( any e ) {
			// Ignore any errors poking around the local Maven repo (permissions, missing drive, etc.) —
			// it's a convenience check, never a hard requirement.
		}
		return "";
	}

	/**
	 * Build a temp package folder around a jar found in the local Maven repository, mimicking what
	 * the jar: endpoint would produce, but via a local file copy instead of an HTTP download.
	 * @jarPath The absolute path to the local jar file
	 * @artifactId The Maven artifactId (used only to name the copied file)
	 * @version The version (used only to name the copied file)
	 */
	private string function buildPackageFromLocalJar(
		required string jarPath,
		required string artifactId,
		required string version,
		string classifier = ""
	){
		var folderName = tempDir & "/" & "temp" & createUUID();
		directoryCreate( folderName );
		fileCopy( arguments.jarPath, folderName & "/" & arguments.artifactId & "-" & arguments.version & ( arguments.classifier.len() ? "-" & arguments.classifier : "" ) & ".jar" );
		return folderName;
	}

	/**
	 * Converts a Maven-style version range to NPM-style semantic version constraints.
	 * @param range The Maven version range as a string (e.g., "[1.2.0,2.0.0)").
	 * @return The equivalent NPM-style constraint (e.g., ">=1.2.0 <2.0.0").
	 */
	function convertMavenToNpmVersionRange( required string range ){
		// Only Maven's bracket-range syntax (e.g. "[1.2.0,2.0.0)") needs converting.  Anything else
		// is already a plain version string and should pass through as-is — don't gate this on
		// semanticVersion.isExactVersion(), since real Maven versions are often 1 or 2 segments
		// (e.g. "1.1", "2") which isExactVersion() doesn't consider "exact" (it expects x.y.z).
		if ( !reFind( "^[\[\(]", range ) ) {
			return range;
		}

		var pattern = "([\[\(])([\d\.]+),([\d\.]+)([\]\)])";
		// reFind( ..., true ) returns a struct of { pos: [...], len: [...] } — NOT a flat array of
		// matched substring text — index 1 is the whole match, 2-5 are the four capture groups.
		// A failed match returns pos = [ 0 ].
		var matches = reFind( pattern, range, 1, true );

		if ( !arrayLen( matches.pos ) || matches.pos[ 1 ] == 0 ) {
			throw( message = "Invalid version range format: #range#", type = "endpointException" );
		}

		var lowerBoundSymbol = mid( range, matches.pos[ 2 ], matches.len[ 2 ] ) EQ "[" ? ">=" : ">";
		var lowerVersion     = mid( range, matches.pos[ 3 ], matches.len[ 3 ] );
		var upperVersion     = mid( range, matches.pos[ 4 ], matches.len[ 4 ] );
		var upperBoundSymbol = mid( range, matches.pos[ 5 ], matches.len[ 5 ] ) EQ "]" ? "<=" : "<";

		return lowerBoundSymbol & lowerVersion & " " & upperBoundSymbol & upperVersion;
	}

	/**
	 * Parse a POM file
	 * @xmlString The XML string to parse
	 * @repo The repository the POM was fetched from (used to resolve parent POMs).  Optional.
	 */
	private function parsePOM( xmlString, string repo = "" ){
		var pom = {
			"name"         : "",
			"packaging"    : "",
			"dependencies" : [],
			// <dependencyManagement> entries flattened across the parent chain, keyed by "groupId:artifactId".
			// Used to fill in missing version/scope on <dependencies> — NOT a list of things to install.
			"managed"      : {},
			"xml"          : {}
		};
		var xml = "";
		var dep = "";
		var d   = "";
		if ( !isSafeXML( xmlString ) ) {
			throw( message = "POM XML Contained Potentially Unsafe Directives", type = "endpointException" );
		}
		xml = xmlParse( xmlString );
		if ( xml.xmlRoot.keyExists( "name" ) ) {
			pom.name = xml.xmlRoot.name.xmlText;
		}
		if ( xml.xmlRoot.keyExists( "packaging" ) ) {
			pom.packaging = xml.xmlRoot.packaging.xmlText;
		}
		pom.xml = xml;

		// Walk the <parent> chain once, so property lookups can see inherited values.
		// Only walk when we know which repo to fetch from.
		var ancestors = arguments.repo.len() ? buildAncestors( xml, arguments.repo ) : [];

		// Build the merged <dependencyManagement> map.  Child POM wins over parents (Maven semantics).
		// We walk furthest-ancestor -> closest-ancestor -> current POM, so later writes shadow earlier ones.
		// The chain is [ current, parent, grandparent, ... ]; iterate in reverse so we write oldest first.
		var chain = [ xml ];
		for ( var a in ancestors ) {
			arrayAppend( chain, a );
		}
		for ( var i = arrayLen( chain ); i >= 1; i-- ) {
			var doc = chain[ i ];
			if ( !doc.XmlRoot.keyExists( "dependencyManagement" ) || !doc.XmlRoot.dependencyManagement.keyExists( "dependencies" ) ) {
				continue;
			}
			// When resolving properties inside this doc's <dependencyManagement>, its own ancestors are the
			// docs that come after it in the chain (its direct parent, grandparent, etc.).
			var docAncestors = [];
			for ( var j = i + 1; j <= arrayLen( chain ); j++ ) {
				arrayAppend( docAncestors, chain[ j ] );
			}
			var managedList = parseDependencies( doc, doc.XmlRoot.dependencyManagement.dependencies, docAncestors, {} );
			for ( var m in managedList ) {
				pom.managed[ m.groupId & ":" & m.artifactId ] = m;
			}
		}

		if ( xml.xmlRoot.keyExists( "dependencies" ) ) {
			pom.dependencies = parseDependencies( xml, xml.xmlRoot.dependencies, ancestors, pom.managed );
		}

		return pom;
	}

	/**
	 * Parse the dependencies from a POM file
	 * @rootXml The root XML object
	 * @node The node to parse
	 * @ancestors Ordered array of parsed parent POM XML docs (immediate parent first).  Optional.
	 * @managed Merged <dependencyManagement> map from the parent chain, keyed by "groupId:artifactId".  Optional.
	 */
	private function parseDependencies( rootXml, node, array ancestors = [], struct managed = {} ){
		var dep  = "";
		var d    = "";
		var deps = [];
		// Default scope is compile: https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html
		for ( dep in node.XmlChildren ) {
			d = {
				"groupId"    : "",
				"artifactId" : "",
				"scope"      : "",
				"type"       : "",
				"version"    : "",
				"optional"   : false,
				// POM-native <exclusions> declared on THIS dependency edge — "groupId:artifactId" strings.
				// Only applies to this dependency's own subtree, not siblings.
				"exclusions" : []
			};
			d.groupId    = resolveProperty( dep.groupId.XmlText, arguments.rootXml, arguments.ancestors );
			d.artifactId = resolveProperty( dep.artifactId.xmlText, arguments.rootXml, arguments.ancestors );
			if ( dep.keyExists( "version" ) ) {
				d.version = resolveProperty( dep.version.xmlText, arguments.rootXml, arguments.ancestors );
			}
			if ( dep.keyExists( "scope" ) ) {
				d.scope = resolveProperty( dep.scope.xmlText, arguments.rootXml, arguments.ancestors );
			}
			if ( dep.keyExists( "type" ) ) {
				d.type = resolveProperty( dep.type.xmlText, arguments.rootXml, arguments.ancestors );
			}
			if ( dep.keyExists( "optional" ) ) {
				// XML text is always a string; interpret "true" (case-insensitive) as boolean true.
				var optText = resolveProperty( dep.optional.xmlText, arguments.rootXml, arguments.ancestors );
				d.optional  = ( isBoolean( optText ) && optText );
			}
			if ( dep.keyExists( "exclusions" ) ) {
				for ( var exclusionNode in dep.exclusions.XmlChildren ) {
					if ( !exclusionNode.keyExists( "groupId" ) || !exclusionNode.keyExists( "artifactId" ) ) {
						continue;
					}
					var exclGroupId    = resolveProperty( exclusionNode.groupId.xmlText, arguments.rootXml, arguments.ancestors );
					var exclArtifactId = resolveProperty( exclusionNode.artifactId.xmlText, arguments.rootXml, arguments.ancestors );
					arrayAppend( d.exclusions, exclGroupId & ":" & exclArtifactId );
				}
			}

			// Fill in missing version/scope/type from <dependencyManagement> inheritance.
			var mgmtKey = d.groupId & ":" & d.artifactId;
			if ( arguments.managed.keyExists( mgmtKey ) ) {
				var mgmt = arguments.managed[ mgmtKey ];
				if ( !d.version.len() && mgmt.version.len() ) {
					d.version = mgmt.version;
				}
				if ( !d.scope.len() && mgmt.scope.len() ) {
					d.scope = mgmt.scope;
				}
				if ( !d.type.len() && mgmt.type.len() ) {
					d.type = mgmt.type;
				}
			}

			// Apply Maven default scope of "compile" if still unset.
			if ( !d.scope.len() ) {
				d.scope = "compile";
			}

			arrayAppend( deps, d );
		}
		return deps;
	}

	/**
	 * Walk the <parent> chain of a POM, fetching each ancestor POM in order.
	 * Returns an array of parsed XML documents, immediate parent first.
	 * Guards against cycles and caps recursion depth.
	 *
	 * @rootXml The current POM XML document
	 * @repo The repository to fetch parent POMs from
	 */
	private array function buildAncestors( required rootXml, required string repo ){
		var ancestors = [];
		var seen      = {};
		var currentXml = arguments.rootXml;
		var maxDepth  = 10;

		while ( arrayLen( ancestors ) < maxDepth ) {
			var root = currentXml.XmlRoot;
			if ( !root.keyExists( "parent" ) ) {
				break;
			}
			var parentNode = root.parent;
			if (
				!parentNode.keyExists( "groupId" )
				|| !parentNode.keyExists( "artifactId" )
				|| !parentNode.keyExists( "version" )
			) {
				break;
			}
			var key = parentNode.groupId.xmlText & ":" & parentNode.artifactId.xmlText & ":" & parentNode.version.xmlText;
			if ( seen.keyExists( key ) ) {
				// Cycle guard
				break;
			}
			seen[ key ] = true;

			try {
				var parentXml = fetchParentPOMXML(
					parentNode.groupId.xmlText,
					parentNode.artifactId.xmlText,
					parentNode.version.xmlText,
					arguments.repo
				);
			} catch ( any e ) {
				// If we can't fetch a parent, stop walking rather than failing the whole resolve
				break;
			}
			arrayAppend( ancestors, parentXml );
			currentXml = parentXml;
		}
		return ancestors;
	}

	/**
	 * Fetch and parse a parent POM's XML from the given repository.
	 * @groupId The parent groupId
	 * @artifactId The parent artifactId
	 * @version The parent version
	 * @repo The repository to fetch from (URL or alias)
	 */
	private function fetchParentPOMXML(
		required string groupId,
		required string artifactId,
		required string version,
		required string repo
	){
		var addr = getRepoURL( arguments.repo ) & replace( arguments.groupId, ".", "/", "ALL" ) & "/" & arguments.artifactId & "/" & arguments.version & "/" & arguments.artifactId & "-" & arguments.version & ".pom";
		var httpResult = "";

		if ( configService.getSetting( "offlineMode", false ) ) {
			throw(
				message = "Can't download parent POM [#arguments.groupId#:#arguments.artifactId#:#arguments.version#], CommandBox is in offline mode.",
				type    = "endpointException"
			);
		}

		cfhttp(
			url           = "#addr#",
			proxyServer   = "#configService.getSetting( "proxy.server", "" )#",
			proxyPort     = "#configService.getSetting( "proxy.port", 80 )#",
			proxyUser     = "#configService.getSetting( "proxy.user", "" )#",
			proxyPassword = "#configService.getSetting( "proxy.password", "" )#",
			method        = "get",
			redirect      = true,
			timeout       = 20,
			result        = "httpResult"
		);

		if ( !( httpResult.statusCode contains "200" ) ) {
			throw( message = "Parent POM request to #addr# returned status: #httpResult.statusCode#", type = "endpointException" );
		}
		if ( !isSafeXML( httpResult.fileContent ) ) {
			throw( message = "Parent POM XML Contained Potentially Unsafe Directives", type = "endpointException" );
		}
		return xmlParse( httpResult.fileContent );
	}

	/**
	 * Resolve Maven POM property placeholders (e.g. ${project.groupId}, ${project.version}, ${some.custom.prop})
	 * in a string value.  Walks the parent POM chain looking for <properties> entries and project.* built-ins.
	 * Unresolved placeholders are left as-is.
	 *
	 * @value The raw string value that may contain ${...} placeholders
	 * @rootXml The parsed POM XML document
	 * @ancestors Ordered array of parsed parent POM XML docs (immediate parent first).  Optional.
	 */
	private function resolveProperty( required string value, required rootXml, array ancestors = [] ){
		if ( !find( "${", arguments.value ) ) {
			return arguments.value;
		}

		// Build the full chain: current POM first, then ancestors from closest to furthest.
		var chain = [ arguments.rootXml ];
		for ( var a in arguments.ancestors ) {
			arrayAppend( chain, a );
		}

		var resolved = arguments.value;

		// Resolve built-in project.* references from the *current* POM only, walking
		// the <parent> element and ancestor chain when a field isn't defined locally.
		var projectGroupId    = findProjectField( chain, "groupId" );
		var projectVersion    = findProjectField( chain, "version" );
		var projectArtifactId = findProjectField( chain, "artifactId" );
		var rootNode          = arguments.rootXml.XmlRoot;
		var parentGroupId     = rootNode.keyExists( "parent" ) && rootNode.parent.keyExists( "groupId" ) ? rootNode.parent.groupId.xmlText : "";
		var parentVersion     = rootNode.keyExists( "parent" ) && rootNode.parent.keyExists( "version" ) ? rootNode.parent.version.xmlText : "";

		var builtIns = {
			"${project.groupId}"        : projectGroupId,
			"${pom.groupId}"            : projectGroupId,
			"${project.version}"        : projectVersion,
			"${pom.version}"            : projectVersion,
			"${project.artifactId}"     : projectArtifactId,
			"${pom.artifactId}"         : projectArtifactId,
			"${project.parent.groupId}" : parentGroupId,
			"${project.parent.version}" : parentVersion
		};

		for ( var placeholder in builtIns ) {
			if ( find( placeholder, resolved ) && builtIns[ placeholder ].len() ) {
				resolved = replace( resolved, placeholder, builtIns[ placeholder ], "all" );
			}
		}

		// Walk <properties> across the chain (current POM first, then ancestors).
		// Child <properties> shadow parent <properties>.
		if ( find( "${", resolved ) ) {
			for ( var doc in chain ) {
				if ( !find( "${", resolved ) ) {
					break;
				}
				var node = doc.XmlRoot;
				if ( !node.keyExists( "properties" ) ) {
					continue;
				}
				for ( var prop in node.properties.XmlChildren ) {
					var token = "${" & prop.XmlName & "}";
					if ( find( token, resolved ) ) {
						resolved = replace( resolved, token, prop.xmlText, "all" );
					}
				}
			}
		}

		return resolved;
	}

	/**
	 * Find a project.* field (groupId, version, artifactId) by walking a POM chain.
	 * Prefers the field defined directly on the POM, then falls back to its <parent> element,
	 * then to the next ancestor's own field, and so on.
	 *
	 * @chain Ordered array of parsed POM XML docs (current POM first, then ancestors).
	 * @fieldName The element name to look for (groupId, version, artifactId).
	 */
	private string function findProjectField( required array chain, required string fieldName ){
		for ( var doc in arguments.chain ) {
			var root = doc.XmlRoot;
			if ( root.keyExists( arguments.fieldName ) ) {
				return root[ arguments.fieldName ].xmlText;
			}
			if ( root.keyExists( "parent" ) && root.parent.keyExists( arguments.fieldName ) ) {
				return root.parent[ arguments.fieldName ].xmlText;
			}
		}
		return "";
	}

	/**
	 * Check if an XML string is safe
	 * @xml The XML string to check
	 */
	private function isSafeXML( xml ){
		if ( findNoCase( "!doctype", arguments.xml ) ) {
			return false;
		}
		if ( findNoCase( "!entity", arguments.xml ) ) {
			return false;
		}
		if ( findNoCase( "!element", arguments.xml ) ) {
			return false;
		}
		if ( find( "XInclude", arguments.xml ) ) {
			return false;
		}
		// may be safe
		return true;
	}

}
