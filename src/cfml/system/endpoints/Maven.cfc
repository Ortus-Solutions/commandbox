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
	property name="namePrefixes" type="string";
	property name="globalRepos"  type="struct";

	// Constructor
	function init(){
		setNamePrefixes( "maven" );
		var orderedStruct                  = structNew( "ordered" );
		orderedStruct[ "mavenCentral" ]    = "https://maven-central.storage.googleapis.com/maven2/";
		orderedStruct[ "sonatype" ]        = "https://oss.sonatype.org/content/repositories/releases/";
		orderedStruct[ "jitpack" ]         = "https://jitpack.io/";
		orderedStruct[ "google" ]          = "https://maven.google.com/";
		orderedStruct[ "spring" ]          = "https://repo.spring.io/release/";
		orderedStruct[ "jboss" ]           = "https://repository.jboss.org/nexus/content/repositories/releases/";
		orderedStruct[ "apacheSnapshots" ] = "https://repository.apache.org/snapshots/";
		orderedStruct[ "gradlePlugins" ]   = "https://plugins.gradle.org/m2/";
		setGlobalRepos( orderedStruct );
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
		var job   = wirebox.getInstance( "interactiveJob" );
		var repos = getGlobalRepos(); // Global linked struct of repos
		// var projectRepos = {}; // TODO: Local overrides from box.json
		// var repos = structAppend(globalRepos, projectRepos, false); // Preserve order

		var artifactParts = getArtifactParts( package );
		var jarFileURL    = "";
		var artifact      = {
			"jarFileURL"       : "",
			"artifactMetadata" : {}
		};

		// If the local artifact exists, serve it
		if (
			artifactService.artifactExists( artifactParts.artifactId, artifactParts.version ) && artifactParts.version != "STABLE" && !semanticVersion.isExactVersion(
				artifactParts.version,
				true
			)
		) {
			job.addLog( "Lucky you, we found this version in local artifacts!" );
			var thisArtifactPath = artifactService.getArtifactPath( artifactParts.artifactId, artifactParts.version );

			// Return the path to the artifact
			return fileEndpoint.resolvePackage(
				thisArtifactPath,
				currentWorkingDirectory,
				arguments.verbose
			);
		}

		// Check only the explicitly defined repo, if any
		if ( len( artifactParts.repo ) ) {
			artifact = getArtifactFromRepo(
				artifactParts.repo,
				artifactParts.groupId,
				artifactParts.artifactId,
				artifactParts.version
			);
			jarFileURL = artifact.jarFileURL;
		}
		// Otherwise, check each registered repo sequentially
		else {
			for ( var alias in repos ) {
				artifact = getArtifactFromRepo(
					repos[ alias ],
					artifactParts.groupId,
					artifactParts.artifactId,
					artifactParts.version
				);
				jarFileURL = artifact.jarFileURL;
				// If we found the artifact, break out of the loop
				if ( jarFileURL.len() ) {
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

		if ( artifactParts.version eq "STABLE" ) {
			artifactParts.version = getLatestVersion( artifactParts.groupId, artifactParts.artifactId );
		}

		// Update artifact version if it's a range
		else if ( !semanticVersion.isExactVersion( artifactParts.version, true ) ) {
			if (
				artifact.artifactMetadata.keyExists( "versioning" ) && artifact.artifactMetadata.versioning.keyExists( "versions" ) && artifact.artifactMetadata.versioning.versions.len()
			) {
				var sortedVersions = artifact.artifactMetadata.versioning.versions.sort( ( a, b ) => variables.semanticVersion.compare( b, a ) );
				// Get the latest version that matches the range
				for ( var thisVersion in sortedVersions ) {
					if ( semanticVersion.satisfies( thisVersion, artifactParts.version ) ) {
						artifactParts.version = thisVersion;
						break;
					}
				}
			}
		}

		// get dependencies
		var artifactDependencies = getArtifactAndDependencyJarURLs(
			artifactParts.groupId,
			artifactParts.artifactId,
			artifactParts.version
		);

		var installPaths = {};
		var dependencies = {};

		for ( var dependency in artifactDependencies ) {
			if ( dependency.artifactId == artifactParts.artifactId ) {
				continue;
			}
			dependencies[ dependency.artifactId ] = getNamePrefixes() & (
				artifactParts.repo.len() ? artifactParts.repo & "|" : ""
			) & dependency.groupId & ":" & dependency.artifactId & ":" & dependency.version;
			installPaths[ dependency.artifactId ] = "lib/" & dependency.artifactId;
		}

		// override the box.json with the actual version and dependencies
		var boxJSON = {
			"name"         : "#artifactParts.groupId & "-" & artifactParts.artifactId#.jar",
			"slug"         : artifactParts.artifactId,
			"version"      : artifactParts.version,
			"location"     : "maven:" & arguments.package,
			"type"         : "jars",
			"dependencies" : dependencies,
			"installPaths" : installPaths
		};

		JSONService.writeJSONFile( folderName & "/box.json", boxJSON );

		job.addLog( "Storing download in artifact cache..." );

		// store it locally in the artifact cache
		artifactService.createArtifact(
			artifactParts.artifactId,
			artifactParts.version,
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
	 * checks if an artifact exists in the given repository and gets it
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
		switch ( repo ) {
			case "https://maven-central.storage.googleapis.com/maven2/":
			case "mavenCentral":
			case "maven":
				return getArtifactFromMavenCentral( groupId, artifactId, version );
			case "https://oss.sonatype.org/content/repositories/releases/":
			case "https://jitpack.io/":
			case "https://maven.google.com/":
			case "https://repo.spring.io/release/":
			case "https://repository.jboss.org/nexus/content/repositories/releases/":
			case "https://repository.apache.org/snapshots/":
			case "https://plugins.gradle.org/m2/":
				throw "Repo not implemented yet: " & repo;
				break;
			default:
				throw "Unsupported repository: " & repo;
		}
	}

	/**
	 * Get an artifact from Maven Central
	 * @groupId The group ID of the artifact
	 * @artifactId The artifact ID
	 * @version The version of the artifact
	 */
	private function getArtifactFromMavenCentral(
		string groupId,
		string artifactId,
		string version
	){
		var artifact = {
			"jarFileURL"       : "",
			"artifactMetadata" : {}
		}
		// get artifact metadata to make sure it exists
		try {
			var artifact.artifactMetadata = getArtifactMetadataFromMaven( arguments.groupId, arguments.artifactId );
		} catch ( Any e ) {
			throw(
				"Could not find artifact metadata for [#arguments.groupId#:#arguments.artifactId#] in maven central repository",
				"endpointException",
				e.detail
			);
		}

		// Get latest version if not specified
		if ( arguments.version eq "STABLE" ) {
			latestVersion       = getLatestVersion( arguments.groupId, arguments.artifactId );
			artifact.jarFileURL = getJarFileURL(
				arguments.groupId,
				arguments.artifactId,
				latestVersion
			);
			return artifact;
		} else {
			// Check if the version is a range
			if ( !semanticVersion.isExactVersion( arguments.version ) ) {
				if (
					artifact.artifactMetadata.keyExists( "versioning" ) && artifact.artifactMetadata.versioning.keyExists( "versions" ) && artifact.artifactMetadata.versioning.versions.len()
				) {
					var sortedVersions = artifact.artifactMetadata.versioning.versions.sort( ( a, b ) => variables.semanticVersion.compare( b, a ) );
					// Get the latest version that matches the range
					for ( var thisVersion in sortedVersions ) {
						if ( semanticVersion.satisfies( thisVersion, arguments.version ) ) {
							artifact.jarFileURL = getJarFileURL(
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
	 * @groupId The group ID of the artifact
	 * @artifactId The artifact ID
	 */
	private function getLatestVersion( string groupId, string artifactId ){
		var metadata = getArtifactMetadataFromMaven( groupId, artifactId );

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
	 * @groupId The group ID of the artifact
	 * @artifactId The artifact ID
	 */
	private function getArtifactMetadataFromMaven( groupId, artifactId ){
		var repoURL    = getGlobalRepos().mavenCentral;
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
	 * Get the version of an artifact from Maven Central
	 * @groupId The group ID of the artifact
	 * @artifactId The artifact ID
	 * @version The version of the artifact
	 */
	private function getArtifactVersion( groupId, artifactId, version ){
		var job        = wirebox.getInstance( "interactiveJob" );
		var addr       = getGlobalRepos().mavenCentral & replace( groupId, ".", "/", "ALL" ) & "/" & artifactId & "/" & version & "/" & artifactId & "-" & version & ".pom";
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
	 * @groupId The group ID of the artifact
	 * @artifactId The artifact ID
	 * @version The version of the artifact
	 * @scopes The scopes to include
	 * @depth The depth of the dependencies
	 */
	private function getArtifactAndDependencyJarURLs(
		groupId,
		artifactId,
		version,
		scopes = "runtime,compile",
		depth  = 0
	){
		var meta   = getArtifactVersion( groupId, artifactId, version );
		var cache  = {};
		var result = [];
		var dep    = "";
		var d      = "";
		var v      = "";
		if ( meta.packaging IS "jar" ) {
			result = [
				{
					"download"   : getJarFileURL( groupId, artifactId, version ),
					"groupId"    : arguments.groupId,
					"artifactId" : arguments.artifactId,
					"version"    : arguments.version
				}
			];
		}
		for ( dep in meta.dependencies ) {
			if ( !listFindNoCase( arguments.scopes, dep.scope ) ) {
				// skip
				continue;
			}
			if ( dep.optional ) {
				continue;
			}
			if ( !cache.keyExists( dep.groupId & "/" & dep.artifactId ) ) {
				d = getArtifactMetadataFromMaven( dep.groupId, dep.artifactId );
				if ( len( dep.version ) ) {
					d.wantedVersion = [ dep.version ];
				}
				cache[ dep.groupId & "/" & dep.artifactId ] = d;
			} else if ( len( dep.version ) ) {
				// add as a wanted version
				arrayAppend( cache[ dep.groupId & "/" & dep.artifactId ].wantedVersion, dep.version );
			}
		}

		for ( dep in cache ) {
			dep = cache[ dep ];
			if ( !dep.keyExists( "wantedVersion" ) ) {
				v = dep.versioning.release;
			} else {
				// todo pick highest version
				v = dep.wantedVersion[ 1 ];
			}
			if ( dep.artifactId == arguments.artifactId && dep.groupId == arguments.groupId ) {
				continue;
			}
			if ( meta.packaging IS "pom" && dep.scope IS "import" ) {
				if ( depth > 10 ) {
					throw( message = "Maximum depth of 10 reached" );
				}
				d = getArtifactAndDependencyJarURLs(
					dep.groupId,
					dep.artifactId,
					v,
					scopes,
					depth++
				);
				for ( v in d ) {
					if ( !arrayFind( result, v ) ) {
						arrayAppend( result, v );
					}
				}
			} else {
				arrayAppend(
					result,
					{
						"download"   : getJarFileURL( dep.groupId, dep.artifactId, v ),
						"groupId"    : dep.groupId,
						"artifactId" : dep.artifactId,
						"version"    : v
					}
				);
			}
		}
		return result;
	}

	/**
	 * Get the URL for a JAR file
	 * @groupId The group ID of the artifact
	 * @artifactId The artifact ID
	 * @version The version of the artifact
	 */
	private function getJarFileURL( groupId, artifactId, version ){
		var addr = getGlobalRepos().mavenCentral & replace( groupId, ".", "/", "ALL" ) & "/" & artifactId & "/" & version & "/" & artifactId & "-" & version & ".jar";
		return addr;
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
