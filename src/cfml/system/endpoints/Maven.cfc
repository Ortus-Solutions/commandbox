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

	// Properties
	property name="namePrefixes"    type="string";
	property name="defaultRepo"     type="struct";
	property name="registeredRepos" type="struct";

	// Constructor
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

		variables.registeredRepos = variables.configService.getSetting( "endpoints.maven", getDefaultRepo() );
		// Preserve order and allow overrides
		structAppend(
			variables.registeredRepos,
			getProjectRepos( currentWorkingDirectory ),
			true
		);

		var artifact = {
			"parts"      : getArtifactParts( package ),
			"jarFileURL" : "",
			"metadata"   : {}
		};

		// If the repo is empty, default it to mavenCentral
		if ( !artifact.parts.repo.len() ) {
			artifact.parts.repo = "mavenCentral";
		}

		job.addLog( "Resolving Maven artifact: #artifact.parts.repo#" );

		// If the local artifact exists, serve it
		if (
			artifactService.artifactExists( artifact.parts.repo & artifact.parts.groupId & artifact.parts.artifactId, artifact.parts.version ) && artifact.parts.version != "STABLE" && !semanticVersion.isExactVersion(
				artifact.parts.version,
				true
			)
		) {
			job.addLog( "Lucky you, we found this version in local artifacts!" );
			var thisArtifactPath = artifactService.getArtifactPath( artifact.parts.repo & artifact.parts.groupId & artifact.parts.artifactId, artifact.parts.version );

			// Return the path to the artifact
			return fileEndpoint.resolvePackage(
				thisArtifactPath,
				currentWorkingDirectory,
				arguments.verbose
			);
		}

		// Check only the explicitly defined repo, if any
		if ( len( artifact.parts.repo ) ) {
			var returnedArtifact = getArtifactFromRepo(
				artifact.parts.repo,
				artifact.parts.groupId,
				artifact.parts.artifactId,
				artifact.parts.version
			);
			artifact.metadata   = returnedArtifact.metadata;
			artifact.jarFileURL = returnedArtifact.jarFileURL;
		}
		// Otherwise, check each registered repo sequentially
		else {
			for ( var alias in getRegisteredRepos() ) {
				var returnedArtifact = getArtifactFromRepo(
					getRegisteredRepos()[ alias ],
					artifact.parts.groupId,
					artifact.parts.artifactId,
					artifact.parts.version
				);
				artifact.metadata   = returnedArtifact.metadata;
				artifact.jarFileURL = returnedArtifact.jarFileURL;
				// If we found the artifact, break out of the loop
				if ( artifact.jarFileURL.len() ) {
					break;
				}
			}
		}

		// Defer to jar endpoint
		var folderName = jarEndpoint.resolvePackage(
			artifact.jarFileURL,
			currentWorkingDirectory,
			arguments.verbose
		);

		if ( artifact.parts.version eq "STABLE" ) {
			artifact.parts.version = getLatestVersion(
				artifact.parts.repo,
				artifact.parts.groupId,
				artifact.parts.artifactId
			);
		}

		// Update artifact version if it's a range
		else if ( !semanticVersion.isExactVersion( artifact.parts.version, true ) ) {
			job.addLog( "It's a range: #artifact.parts.version#" );
			if (
				artifact.metadata.keyExists( "versioning" ) && artifact.metadata.versioning.keyExists( "versions" ) && artifact.metadata.versioning.versions.len()
			) {
				var sortedVersions = artifact.metadata.versioning.versions.sort( ( a, b ) => variables.semanticVersion.compare( b, a ) );
				// Get the latest version that matches the range
				for ( var thisVersion in sortedVersions ) {
					if ( semanticVersion.satisfies( thisVersion, artifact.parts.version ) ) {
						job.addLog( "VERSION FOUND: #thisVersion#" );
						artifact.parts.version = thisVersion;
						break;
					}
				}
			}
		}

		job.addLog( "VERSION: #artifact.parts.version#" );

		// Get dependencies
		var artifactDependencies = getArtifactAndDependencyJarURLs(
			artifact.parts.repo,
			artifact.parts.groupId,
			artifact.parts.artifactId,
			artifact.parts.version
		);

		var installPaths = {};
		var dependencies = {};

		for ( var dependency in artifactDependencies ) {
			if ( dependency.artifactId == artifact.parts.artifactId ) {
				continue;
			}
			dependencies[ dependency.artifactId ] = getNamePrefixes() & ":" & (
				artifact.parts.repo.len() && artifact.parts.repo neq "mavenCentral" ? artifact.parts.repo & "|" : ""
			) & dependency.groupId & ":" & dependency.artifactId & ":" & convertMavenToNpmVersionRange(
				dependency.version
			);
			installPaths[ dependency.artifactId ] = "lib/" & dependency.artifactId;
		}

		// Override the box.json with the actual version and dependencies
		var boxJSON = {
			"name"         : "#artifact.parts.groupId & "-" & artifact.parts.artifactId#.jar",
			"slug"         : artifact.parts.groupId & "-" & artifact.parts.artifactId,
			"version"      : artifact.parts.version,
			"location"     : getNamePrefixes() & ":" & arguments.package,
			"type"         : "jars",
			"dependencies" : dependencies,
			"installPaths" : installPaths
		};

		JSONService.writeJSONFile( folderName & "/box.json", boxJSON );

		job.addLog( "Storing download in artifact cache..." );

		// Store it locally in the artifact cache
		artifactService.createArtifact(
			artifact.parts.repo & artifact.parts.groupId & artifact.parts.artifactId,
			artifact.parts.version,
			folderName
		);

		job.addLog( "Done." );

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
	function getProjectRepos( string currentWorkingDirectory ){
		var boxJSONPath = currentWorkingDirectory & "/box.json";

		if ( fileExists( boxJSONPath ) ) {
			var boxJSON = deserializeJSON( fileRead( boxJSONPath ) );

			if ( structKeyExists( boxJSON, "mavenRepositories" ) ) {
				return boxJSON.mavenRepositories;
			}
		}

		return {};
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
		string version
	){
		var artifact = { "jarFileURL" : "", "metadata" : {} }
		// get artifact metadata to make sure it exists
		try {
			var artifact.metadata = getArtifactMetadataFromMaven(
				arguments.repo,
				arguments.groupId,
				arguments.artifactId
			);
		} catch ( Any e ) {
			throw(
				"Could not find artifact metadata for [#arguments.groupId#:#arguments.artifactId#] in #arguments.repo# repository",
				"endpointException",
				e.detail
			);
		}

		// Get latest version if not specified
		if ( arguments.version eq "STABLE" ) {
			latestVersion = getLatestVersion(
				arguments.repo,
				arguments.groupId,
				arguments.artifactId
			);
			artifact.jarFileURL = getJarFileURL(
				arguments.repo,
				arguments.groupId,
				arguments.artifactId,
				latestVersion
			);
			return artifact;
		} else {
			// Check if the version is a range
			if ( !semanticVersion.isExactVersion( arguments.version ) ) {
				if (
					artifact.metadata.keyExists( "versioning" ) && artifact.metadata.versioning.keyExists( "versions" ) && artifact.metadata.versioning.versions.len()
				) {
					var sortedVersions = artifact.metadata.versioning.versions.sort( ( a, b ) => variables.semanticVersion.compare( b, a ) );
					// Get the latest version that matches the range
					for ( var thisVersion in sortedVersions ) {
						if ( semanticVersion.satisfies( thisVersion, arguments.version ) ) {
							artifact.jarFileURL = getJarFileURL(
								arguments.repo,
								arguments.groupId,
								arguments.artifactId,
								thisVersion
							);
							return artifact;
						}
					}
					// If no version was found, throw an error
					throw( "Could not find a version that satisfies the range: #arguments.version#" );
				} else {
					throw( "Could not find versions in artifact metadata" );
				}
			}
			// Get artifact for the passed in version
			artifact.jarFileURL = getJarFileURL(
				arguments.repo,
				arguments.groupId,
				arguments.artifactId,
				arguments.version
			);

			return artifact;
		}
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
	 * Get the latest version of an artifact
	 * @repo The repository to check (URL or alias)
	 * @groupId The group ID of the artifact
	 * @artifactId The artifact ID
	 */
	private function getLatestVersion(
		string repo,
		string groupId,
		string artifactId
	){
		var metadata = getArtifactMetadataFromMaven(
			arguments.repo,
			arguments.groupId,
			arguments.artifactId
		);

		if ( metadata.keyExists( "versioning" ) && metadata.versioning.keyExists( "release" ) ) {
			return metadata.versioning.release;
		} else {
			return "unknown";
		}
	}

	/**
	 * Get the parts of a Maven package string
	 * @package The package string
	 */
	private function getArtifactParts( string package ){
		var response = {
			"repo"       : "",
			"groupId"    : "",
			"artifactId" : "",
			"version"    : ""
		};

		// Remove the 'maven:' prefix from the package
		var packageId = replace(
			arguments.package,
			"maven:",
			"",
			"one"
		);

		// Split the package string by '|' to separate the repo and package
		var parts = listToArray( packageId, "|" );

		// Determine if a custom repo is provided
		if ( arrayLen( parts ) > 1 ) {
			response.repo = parts[ 1 ]; // Use custom repo
			packageId     = parts[ 2 ]; // The actual package
		}

		// Split the package into its components
		var packageParts = listToArray( packageId, ":" );

		// Make sure we have at least the groupId and artifactId
		if ( arrayLen( packageParts ) < 2 ) {
			throw( "Invalid Maven package string: #packageId#" );
		} else {
			response.groupId    = packageParts[ 1 ];
			response.artifactId = packageParts[ 2 ];
			response.version    = packageParts[ 3 ] ?: "STABLE"; // Default to STABLE if not provided
		}

		return response;
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
				"Can't download [#getNamePrefixes()#:#artifactId#], CommandBox is in offline mode.  Go online with [config set offlineMode=false].",
				"endpointException"
			);
		}
		cfhttp(
			url         = "#addr#maven-metadata.xml",
			proxyServer = "#configService.getSetting( "proxy.server", "" )#",
			method      = "get",
			redirect    = true,
			result      = "httpResult"
		);
		if ( httpResult.statusCode contains "200" ) {
			if ( isSafeXML( httpResult.fileContent ) ) {
				metaData      = xmlParse( httpResult.fileContent );
				md.groupId    = metaData.xmlRoot.groupId.XmlText;
				md.artifactId = metaData.xmlRoot.artifactId.XmlText;
				if (
					structKeyExists( metaData.xmlRoot, "versioning" ) && structKeyExists(
						metaData.xmlRoot.versioning,
						"latest"
					) && structKeyExists( metaData.xmlRoot.versioning, "release" )
				) {
					md.versioning.latest  = metaData.xmlRoot.versioning.latest.XmlText;
					md.versioning.release = metaData.xmlRoot.versioning.release.XmlText;
					for ( local.version in metaData.xmlRoot.versioning.versions.XmlChildren ) {
						arrayAppend( md.versioning.versions, local.version.XmlText );
					}
				}
			} else {
				throw( message = "Metadata XML Contained Potentially Unsafe Directives" );
			}
		} else {
			throw( message = "Repository Request to #addr# returned status: #httpResult.statusCode#" );
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
		throw "Invalid repository URL or alias: #arguments.repo#";
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
				"Can't download [#getNamePrefixes()#:#artifactId#], CommandBox is in offline mode.  Go online with [config set offlineMode=false].",
				"endpointException"
			);
		}

		cfhttp(
			url         = "#addr#",
			proxyServer = "#configService.getSetting( "proxy.server", "" )#",
			method      = "get",
			redirect    = true,
			result      = "httpResult"
		);
		if ( httpResult.statusCode contains "200" ) {
			return parsePOM( httpResult.fileContent );
		} else {
			throw( message = "Repository Request to #addr# returned status: #httpResult.statusCode#" );
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
		scopes     = "runtime,compile",
		depthLevel = 0
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
					"version"    : arguments.versionNumber
				}
			];
		}

		for ( dependency in artifactMetadata.dependencies ) {
			if ( !listFindNoCase( arguments.scopes, dependency.scope ) ) {
				// Skip dependencies that are not in the specified scopes
				continue;
			}
			if ( dependency.optional ) {
				continue;
			}
			if ( !dependencyCache.keyExists( dependency.groupId & "/" & dependency.artifactId ) ) {
				dependencyMetadata = getArtifactMetadataFromMaven(
					arguments.repository,
					dependency.groupId,
					dependency.artifactId
				);
				if ( len( dependency.version ) ) {
					dependencyMetadata.wantedVersion = [ dependency.version ];
				}
				dependencyCache[ dependency.groupId & "/" & dependency.artifactId ] = dependencyMetadata;
			} else if ( len( dependency.version ) ) {
				// Add the specified version as a wanted version
				arrayAppend(
					dependencyCache[ dependency.groupId & "/" & dependency.artifactId ].wantedVersion,
					dependency.version
				);
			}
		}

		for ( dependency in dependencyCache ) {
			dependency = dependencyCache[ dependency ];
			if ( !dependency.keyExists( "wantedVersion" ) ) {
				selectedVersion = dependency.versioning.release;
			} else {
				// TODO: Pick the highest version
				selectedVersion = dependency.wantedVersion[ 1 ];
			}
			if ( dependency.artifactId == arguments.artifactIdentifier && dependency.groupId == arguments.groupIdentifier ) {
				continue;
			}
			if ( artifactMetadata.packaging IS "pom" && dependency.scope IS "import" ) {
				if ( depthLevel > 10 ) {
					throw( message = "Maximum depth of 10 reached" );
				}
				dependencyMetadata = getArtifactAndDependencyJarURLs(
					repository,
					dependency.groupId,
					dependency.artifactId,
					selectedVersion,
					scopes,
					depthLevel++
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
						"version"    : selectedVersion
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
	private function getJarFileURL( repo, groupId, artifactId, version ){
		var addr = getRepoURL( arguments.repo ) & replace( groupId, ".", "/", "ALL" ) & "/" & artifactId & "/" & version & "/" & artifactId & "-" & version & ".jar";
		return addr;
	}

	/**
	 * Converts a Maven-style version range to NPM-style semantic version constraints.
	 * @param range The Maven version range as a string (e.g., "[1.2.0,2.0.0)").
	 * @return The equivalent NPM-style constraint (e.g., ">=1.2.0 <2.0.0").
	 */
	function convertMavenToNpmVersionRange( required string range ){
		// If the range is an exact version, return it as-is
		if ( semanticVersion.isExactVersion( range ) ) {
			return range;
		}

		var pattern = "([\[\(])([\d\.]+),([\d\.]+)([\]\)])";
		var matches = reFind( pattern, range, 1, true );

		if ( !matches.len() ) {
			throw( message = "Invalid version range format: #range#", type = "InvalidVersionRangeException" );
		}

		var lowerBoundSymbol = matches[ 2 ] EQ "[" ? ">=" : ">";
		var lowerVersion     = matches[ 3 ];
		var upperVersion     = matches[ 4 ];
		var upperBoundSymbol = matches[ 5 ] EQ "]" ? "<=" : "<";

		return lowerBoundSymbol & lowerVersion & " " & upperBoundSymbol & upperVersion;
	}

	/**
	 * Parse a POM file
	 * @xmlString The XML string to parse
	 */
	private function parsePOM( xmlString ){
		var pom = {
			"name"         : "",
			"packaging"    : "",
			"dependencies" : [],
			"xml"          : {}
		};
		var xml = "";
		var dep = "";
		var d   = "";
		if ( isSafeXML( xmlString ) ) {
			xml = xmlParse( xmlString );
			if ( xml.xmlRoot.keyExists( "name" ) ) {
				pom.name = xml.xmlRoot.name.xmlText;
			}
			if ( xml.xmlRoot.keyExists( "packaging" ) ) {
				pom.packaging = xml.xmlRoot.packaging.xmlText;
			}
			pom.xml = xml;
			if ( xml.xmlRoot.keyExists( "dependencies" ) ) {
				pom.dependencies = parseDependencies( xml, xml.xmlRoot.dependencies );
			}
			if ( xml.xmlRoot.keyExists( "dependencyManagement" ) ) {
				dep = parseDependencies( xml, xml.xmlRoot.dependencyManagement.dependencies );
				if ( arrayIsEmpty( pom.dependencies ) ) {
					pom.dependencies = dep;
				} else {
					for ( d in dep ) {
						arrayAppend( pom.dependencies, d );
					}
				}
			}
		} else {
			throw( message = "POM XML Contained Potentially Unsafe Directives" );
		}
		return pom;
	}

	/**
	 * Parse the dependencies from a POM file
	 * @rootXml The root XML object
	 * @node The node to parse
	 */
	private function parseDependencies( rootXml, node ){
		var dep  = "";
		var d    = "";
		var deps = [];
		var prop = "";
		var p    = "";
		// Default scope is compile: https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html
		for ( dep in node.XmlChildren ) {
			d = {
				"groupId"    : "",
				"artifactId" : "",
				"scope"      : "compile",
				"type"       : "",
				"version"    : "",
				"optional"   : false
			};
			d.groupId    = dep.groupId.XmlText;
			d.artifactId = dep.artifactId.xmlText;
			if ( dep.keyExists( "version" ) ) {
				d.version = dep.version.xmlText;
				if ( d.version == "${project.version}" ) {
					d.version = rootXml.XmlRoot.version.xmlText;
				} else if ( d.version contains "${" && rootXml.XmlRoot.keyExists( "properties" ) ) {
					// check properties ${prop.name}
					for ( prop in rootXml.XmlRoot.properties.XmlChildren ) {
						if ( find( "${" & prop.XmlName & "}", d.version ) ) {
							d.version = replace(
								d.version,
								"${" & prop.XmlName & "}",
								prop.xmlText
							);
						}
					}
				}
			}
			if ( dep.keyExists( "scope" ) ) {
				d.scope = dep.scope.xmlText;
			}
			if ( dep.keyExists( "type" ) ) {
				d.type = dep.type.xmlText;
			}
			if ( dep.keyExists( "optional" ) ) {
				d.optional = dep.optional.xmlText;
			}
			arrayAppend( deps, d );
		}
		return deps;
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
