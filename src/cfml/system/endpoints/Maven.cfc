/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the maven endpoint.  I get packages from the maven repository
*/
component accessors="true" implements="IEndpoint" singleton {

	// DI
	property name="tempDir" 				inject="tempDir@constants";
	property name="semanticVersion"			inject="provider:semanticVersion@semver";
	property name="progressableDownloader" 	inject="ProgressableDownloader";
	property name="progressBar" 			inject="ProgressBar";
	property name='JSONService'				inject='JSONService';
	property name='configService'			inject='configService';
	property name='wirebox'					inject='wirebox';

	// Properties
	property name="namePrefixes" type="string";
	property name="repositoryBaseURL" type="string";

	// Constructor
	function init() {
		setNamePrefixes( 'maven' );
		setRepositoryBaseURL( "https://maven-central.storage.googleapis.com/maven2/" );
		variables.defaultVersion = '0.0.0';
		return this;
	}

	/**
     * Resolves the Maven package based on the provided package string.
     * Handles different URL patterns for Maven repositories.
	 * @package The package to resolve
	 * @currentWorkingDirectory The directory to resolve the package in
	 * @verbose Verbose flag or silent, defaults to false
     */
	public string function resolvePackage( required string package, string currentWorkingDirectory="", boolean verbose=false ) {
		if( configService.getSetting( 'offlineMode', false ) ) {
			throw( 'Can''t download [#getNamePrefixes()#:#package#], CommandBox is in offline mode.  Go online with [config set offlineMode=false].', 'endpointException' );
		}

		var job = wirebox.getInstance( 'interactiveJob' );
		var packageParts = getPackageParts( package );
		var jarFileURL = "";

        // get artifact metadata to make sure it exists
		try {
			var artifactMetadata = getArtifactMetadata(packageParts.groupId, packageParts.artifactId,packageParts.repoURL);
		} catch(Any e) {
			throw( 'Could not find artifact metadata for [#packageParts.groupId#:#packageParts.artifactId#] in repository [#packageParts.repoURL#]', 'endpointException', e.detail );
		}

		// Get latest version if not specified
		if( packageParts.version eq "LATEST" ) {
			latestVersion = getLatestVersion(packageParts.groupId, packageParts.artifactId, packageParts.repoURL);
			jarFileURL = getJarFileURL(packageParts.groupId, packageParts.artifactId, latestVersion);
			packageParts.version = latestVersion;
		} else {
			// Get artifact version
			jarFileURL = getJarFileURL(packageParts.groupId, packageParts.artifactId, packageParts.version);
		}

		var folderName = tempDir & '/' & 'temp#createUUID()#';
		var fullJarPath = folderName & '/' & getDefaultName( package ) & '.jar';
		var fullBoxJSONPath = folderName & '/box.json';
		directoryCreate( folderName );

		job.addLog( "Downloading [#packageParts.artifactId#]" );

		try {
			// Download File
			var result = progressableDownloader.download(
				jarFileURL, // URL to package
				fullJarPath, // Place to store it locally
				function( status ) {
					progressBar.update( argumentCollection = status );
				},
				function( newURL ) {
					job.addLog( "Redirecting to: '#arguments.newURL#'..." );
				}
			);
		} catch( UserInterruptException var e ) {
			directoryDelete( folderName, true );
			rethrow;
		} catch( Any var e ) {
			directoryDelete( folderName, true );
			throw( '#e.message##e.detail#', 'endpointException' );
		};

		// Spoof a box.json so this looks like a package
		var boxJSON = {
			'name' : '#packageParts.artifactId#.jar',
			'slug' : packageParts.artifactId,
			'version' : packageParts.version,
			'location' : package,
			'type' : 'jars'
		};

		JSONService.writeJSONFile( fullBoxJSONPath, boxJSON );

		// Here is where our alleged so-called "package" lives.
		return folderName;
	}

	/**
	 * Get the default name of a package
	 * @package The package to get the default name for
	 */
	public function getDefaultName( required string package ) {
		// example package string: "maven:https://repo1.maven.com##com.ortusolutions:myPackage:1.2.3-alpha";
		var packageParts = getPackageParts( package );

		if( packageParts.artifactId.len() ) {
			return packageParts.artifactId;
		}

		return reReplaceNoCase( arguments.package, '[^a-zA-Z0-9]', '', 'all' );
	}

	/**
	 * Get an update for a package
	 * @package The package name
	 * @version The package version
	 * @verbose Verbose flag or silent, defaults to false
	 *
	 * @return struct { isOutdated, version }
	 */
	public function getUpdate( required string package, required string version, boolean verbose=false ) {
		// TODO: Review this logic and use semver for version comparison
		packageVersion = guessVersionFromURL( package );
		// No version could be determined from package URL
		if( packageVersion == defaultVersion ) {
			return {
				isOutdated = true,
				version = 'unknown'
			};
		// Our package URL has a version and it's the same as what's installed
		} else if( version == getLatestVersion() ) {
			return {
				isOutdated = false,
				version = getLatestVersion()
			};
		// our package URL has a version and it's not what's installed
		} else {
			return {
				isOutdated = true,
				version = getLatestVersion()
			};
		}
	}

	// Helper function to get the latest version of an artifact
	private function getLatestVersion(string groupId, string artifactId, string repoURL = getRepositoryBaseURL()) {
		var metadata = getArtifactMetadata(groupId, artifactId, repoURL);

		if( metadata.keyExists( "versioning" ) && metadata.versioning.keyExists( "latest" ) ) {
			return metadata.versioning.latest;
		} else {
			return "unknown";
		}
    }

	// Helper function to get the parts of a package string
	private function getPackageParts(string package) {
		var response = {
			"repoURL": getRepositoryBaseURL(),
			"groupId": "",
			"artifactId": "",
			"version": ""
		};

		// Remove the 'maven:' prefix from the package
		package = replace(package, "maven:", "", "one");

		// Split the package string by '#' to separate the repo and package
        var parts = package.split("##");
        
        // Determine if a custom repo is provided
        if (arrayLen(parts) == 2) {
            response.repoURL = parts[1]; // Use custom repo URL
            package = parts[2]; // The actual package
        }

		// Split the package into its components
        var packageParts = package.split(":");

		// Make sure we have at least a groupId and artifactId
		if( arrayLen(packageParts) < 2 ) {
			throw( 'Invalid Maven package string: #package#' );
		} else {
			response.groupId = packageParts[1]; 
			response.artifactId = packageParts[2];
			response.version = packageParts[3] ?: "LATEST"; // Default to LATEST if not provided
		}

		return response;
    }

	// Helper function to get the parts of a package string
	private function guessVersionFromURL( required string package ) {
		var version = package;
		if( version contains '/' ) {
			var version = version
				.reReplaceNoCase( '^([\w:]+)?//', '' )
				.listRest( '/\' );
		}
		if( version.refindNoCase( '.*([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}).*' ) ) {
			version = version.reReplaceNoCase( '.*([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}).*', '\1' );
		} else {
			version = defaultVersion;
		}
		return version;
	}

	// Helper function to get the artifact metadata
	private function getArtifactMetadata(groupId, artifactId, repoURL = getRepositoryBaseURL() ) {
		var addr = repoURL & replace(groupId, ".", "/", "ALL") & "/" & artifactId & "/";
		var httpResult = "";
		var metaData = "";
		var md = {"groupId":"", "artifactId":"", "versioning": {"latest":"", "release":"", "versions":[], "lastUpdated":""}};
		cfhttp(url="#addr#maven-metadata.xml", method="get", redirect=true, result="httpResult");
		if (httpResult.statusCode contains "200"){
			if (isSafeXML(httpResult.fileContent)) {
				metaData = xmlParse(httpResult.fileContent);
				md.groupId = metaData.xmlRoot.groupId.XmlText;
				md.artifactId = metaData.xmlRoot.artifactId.XmlText;
				if (structKeyExists(metaData.xmlRoot, "versioning")) {
					md.versioning.latest = metaData.xmlRoot.versioning.latest.XmlText;
					md.versioning.release = metaData.xmlRoot.versioning.release.XmlText;
					for (local.version in metaData.xmlRoot.versioning.versions.XmlChildren) {
						arrayAppend(md.versioning.versions, local.version.XmlText);
					}
				}
			} else {
				throw(message="Metadata XML Contained Potentially Unsafe Directives");
			}
			
		} else {
			throw(message="Repository Request to #addr# returned status: #httpResult.statusCode#");
		}
		return md;
	}

	// Helper function to get the artifact version
	private function getArtifactVersion(groupId, artifactId, version) {
		var addr = getRepositoryBaseURL() & replace(groupId, ".", "/", "ALL") & "/" & artifactId & "/" & version & "/" & artifactId & "-" & version & ".pom";
		var httpResult = "";
		
		cfhttp(url="#addr#", method="get", redirect=true, result="httpResult");
		if (httpResult.statusCode contains "200"){
			return parsePOM(httpResult.fileContent);
		} else {
			throw(message="Repository Request to #addr# returned status: #httpResult.statusCode#");
		}
	}

	// Helper function to get the artifact and dependency jar URLs
	private function getArtifactAndDependencyJarURLs(groupId, artifactId, version, scopes="runtime,compile", depth=0) {
		var meta = getArtifactVersion(groupId, artifactId, version);
		var cache = {};
		var result = [];
		var dep = "";
		var d = "";
		var v = "";
		if (meta.packaging IS "jar") {
			result = [{"download":getJarFileURL(groupId, artifactId, version), "groupId":arguments.groupId, "artifactId":arguments.artifactId, "version":arguments.version}];
		}
		for (dep in meta.dependencies) {
			if (!listFindNoCase(arguments.scopes, dep.scope)) {
				//skip
				continue;
			}
			if (dep.optional) {
				continue;
			}
			if (!cache.keyExists(dep.groupId & "/" & dep.artifactId)) {
				d = getArtifactMetadata(dep.groupId, dep.artifactId);
				if (len(dep.version)) {
					d.wantedVersion = [dep.version];
				}
				cache[dep.groupId & "/" & dep.artifactId] = d;
			} else if (len(dep.version)) {
				//add as a wanted version
				arrayAppend(cache[dep.groupId & "/" & dep.artifactId].wantedVersion, dep.version);
			}
		}
		
		for (dep in cache) {
			dep = cache[dep];
			if (!dep.keyExists("wantedVersion")) {
				v = dep.versioning.release;
			} else {
				//todo pick highest version
				v = dep.wantedVersion[1];
			}
			if (dep.artifactId == arguments.artifactId && dep.groupId == arguments.groupId) {
				continue;
			}
			if (meta.packaging IS "pom" && dep.scope IS "import") {
				if (depth > 10) {
					throw(message="Maximum depth of 10 reached");
				}
				d = getArtifactAndDependencyJarURLs(dep.groupId, dep.artifactId, v, scopes, depth++);
				for (v in d) {
					if (!arrayFind(result, v)) {
						arrayAppend(result, v);	
					}
				}
			} else {
				arrayAppend(result,{"download":getJarFileURL(dep.groupId, dep.artifactId, v), "groupId":dep.groupId, "artifactId":dep.artifactId, "version":v});
			}
		}
		return result;
	}

	// Helper function to get the jar file URL
	private function getJarFileURL(groupId, artifactId, version) {
		var addr = getRepositoryBaseURL() & replace(groupId, ".", "/", "ALL") & "/" & artifactId & "/" & version & "/" & artifactId & "-" & version & ".jar";
		return addr;
	}

	// Helper function to parse the POM XML
	public function parsePOM(xmlString) {
		var pom = {"name":"", "packaging"="", "dependencies":[], "xml"={}};
		var xml = "";
		var dep = "";
		var d = "";
		if (isSafeXML(xmlString)) {
			xml = xmlParse(xmlString);
			if (xml.xmlRoot.keyExists("name")) {
				pom.name = xml.xmlRoot.name.xmlText;
			}
			if (xml.xmlRoot.keyExists("packaging")) {
				pom.packaging = xml.xmlRoot.packaging.xmlText;
			}
			pom.xml = xml;
			if (xml.xmlRoot.keyExists("dependencies")) {
				pom.dependencies = parseDependencies(xml, xml.xmlRoot.dependencies);
			}
			if (xml.xmlRoot.keyExists("dependencyManagement")) {
				dep = parseDependencies(xml, xml.xmlRoot.dependencyManagement.dependencies);
				if (arrayIsEmpty(pom.dependencies)) {
					pom.dependencies = dep;
				} else {
					for (d in dep) {
						arrayAppend(pom.dependencies, d);
					}
				}
			}
		} else {
			throw(message="POM XML Contained Potentially Unsafe Directives");
		}
		return pom;
	}

	// Helper function to parse the dependencies
	private function parseDependencies(rootXml, node) {
		var dep = "";
		var d = "";
		var deps = [];
		var prop = "";
		var p = "";
		//Default scope is compile: https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html
		for (dep in node.XmlChildren) {
			d = {"groupId":"", "artifactId":"", "scope":"compile", "type":"", "version":"", "optional":false};
			d.groupId = dep.groupId.XmlText;
			d.artifactId = dep.artifactId.xmlText;
			if (dep.keyExists("version")) {
				d.version = dep.version.xmlText;
				if (d.version == "${project.version}") {
					d.version = rootXml.XmlRoot.version.xmlText;
				} else if (d.version contains "${" && rootXml.XmlRoot.keyExists("properties")) {
					//check properties ${prop.name}
					for (prop in rootXml.XmlRoot.properties.XmlChildren) {
						if (find("${" & prop.XmlName & "}", d.version)) {
							d.version = replace(d.version, "${" & prop.XmlName & "}", prop.xmlText);
						}
					}
				}
			}
			if (dep.keyExists("scope")) {
				d.scope = dep.scope.xmlText;
			}
			if (dep.keyExists("type")) {
				d.type = dep.type.xmlText;
			}
			if (dep.keyExists("optional")) {
				d.optional = dep.optional.xmlText;
			}
			arrayAppend(deps, d);
		}
		return deps;
	}

	// Helper function to determine if XML is safe
	private function isSafeXML(xml) {
		if (findNoCase("!doctype", arguments.xml)) {
			return false;
		}
		if (findNoCase("!entity", arguments.xml)) {
			return false;
		}
		if (findNoCase("!element", arguments.xml)) {
			return false;
		}
		if (find("XInclude", arguments.xml)) {
			return false;
		}
		//may be safe
		return true;
	}

}
