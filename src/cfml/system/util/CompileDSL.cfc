/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @description
*
* I am a helper object for executing compile actions for "javac" command and
* jarring actions for "jar" command. Create me and call my
* methods to compile and jar any java project, then .run() will execute me.
*
*/

component accessors=true {

    /* root folder of the project you are working with (compiling, jar) */
    property name='projectRoot'             type="string";
    /* folder inside root project where source files reside (.java) */
    property name='sourceDirectory'         type='string';
    property name='classPaths'      		type='array';
    property name='classOutputDirectory'    type='string';
    property name='verbose'                 type='boolean';
    property name='encode'                  type='string';
	property name='sourcePaths'				type='array';
	property name='createJar'				type='boolean';
	property name='jarNameString'			type='string';
	property name='fatJarNameString'		type='string';
	property name='generatedJarPath'			type='string';
	property name='libsDir'					type='string';
	property name='compileOptionsString'	type='string';
	property name='compileOptionsParams'	type='struct';
	property name='jarOptionsString'		type='string';
	property name='jarOptionArguments'		type='string';
	property name='jarOptionsParams'		type='struct';
    property name='javaBinFolder'           type='string';
	property name='customManifest'			type='string';
	property name='customManifestParams'	type='struct';
	property name='generatedManifestFile'	type='string';
	property name='resourcePath'			type='string';
	property name='resourcePathConfigured'	type='boolean';
	property name='classTextFilePaths'		type='array';
	property name='fatJarPaths'				type='array';
	property name='fatJarOptions'			type='struct';
	property name='fatJarDuplicateReport'	type='array';
	property name='thinJarRequested'		type='boolean';
	property name='fatJarRequested'			type='boolean';
	property name='javaDocDestinationDir'	type='string';
	property name='useJavaDoc'				type='boolean';

    //DI
	property name="packageService"	inject="PackageService";
    property name='wirebox'         inject='wirebox';
    property name='fileSystemUtil'  inject='FileSystem';
	property name='shell'	        inject='shell';
    property name='job'		        inject='interactiveJob';
    property name='endpointService'	inject='endpointService';
    property name='javaService'		inject='javaService';
	property name="tempDir" 		inject="tempDir@constants";

    /*
    have a classpath
    have a verbose flag
    have a encoding flag option
    */

	/**
	 * Initializes the Compile DSL with its default paths and options.
	 *
	 * @returns The initialized DSL instance.
	 */
	public function init() {
        setSourceDirectory( 'src/main/java/' );
        setClassOutputDirectory( 'build/classes/java/main' );
        setVerbose( false );
        setEncode( '' );
		setClassPaths( [] );
		setSourcePaths( [''] );
		setCreateJar( false );
		setLibsDir( 'build/libs' );
		setCompileOptionsString( '' );
		setCompileOptionsParams( {} );
		setJarOptionsString( '' );
		setJarOptionArguments( '' );
		setJarOptionsParams( {} );
		setJarNameString( '' );
		setFatJarNameString( '' );
		setGeneratedJarPath( '' );
		setCustomManifest( '' );
		setCustomManifestParams( {} );
		setGeneratedManifestFile( '' );
		setResourcePath( 'src/main/resources/' );
		setResourcePathConfigured( false );
		setClassTextFilePaths(['']);
		setFatJarPaths( [] );
		setFatJarDuplicateReport( [] );
		setThinJarRequested( false );
		setFatJarRequested( false );
		setFatJarOptions( {
			"mergeServiceDescriptors" : true,
			"excludeSignatures"       : true,
			"duplicatePolicy"         : "last"
		} );
		setJavaDocDestinationDir('build/docs/javadoc');
		setUseJavaDoc(false);
        return this;
    }

	/**
	 * Sets the directory to run the command in
  	 **/
	/**
	 * Sets the project root used to resolve source, class, resource, and JAR paths.
	 *
	 * Any `java` configuration in the project's box.json is applied here as the
	 * baseline defaults. Explicit DSL calls made after projectRoot() always
	 * override those values.
	 *
	 * @projectRoot The project directory to use as the path-resolution root.
	 * @returns The current DSL instance.
	 */
	function projectRoot( required projectRoot ) {
		setProjectRoot( fileSystemutil.resolvePath( projectRoot ) );
		applyBoxJsonDefaults();
		return this;
	}

	/**
	 * Applies the `java` configuration from the project's box.json as baseline
	 * defaults. Keys use the same names as the `java compile` command parameters
	 * so there is one vocabulary across box.json, the CLI, and the DSL.
	 *
	 * @returns The current DSL instance.
	 */
	private function applyBoxJsonDefaults() {
		if( !packageService.isPackage( getProjectRoot() ) ) {
			return this;
		}
		var boxJSON = packageService.readPackageDescriptor( getProjectRoot() );
		var javaConfig = boxJSON.java ?: {};
		if( !isStruct( javaConfig ) || !structCount( javaConfig ) ) {
			return this;
		}

		if( structKeyExists( javaConfig, "source" ) && hasValue( javaConfig.source ) ) fromSource( javaConfig.source );
		if( structKeyExists( javaConfig, "classes" ) && hasValue( javaConfig.classes ) ) toClasses( javaConfig.classes );
		if( structKeyExists( javaConfig, "libsDir" ) && hasValue( javaConfig.libsDir ) ) setLibsDir( javaConfig.libsDir );
		if( structKeyExists( javaConfig, "resources" ) && hasValue( javaConfig.resources ) ) withResources( javaConfig.resources );
		if( structKeyExists( javaConfig, "javaDocsDir" ) && hasValue( javaConfig.javaDocsDir ) ) setJavaDocDestinationDir( javaConfig.javaDocsDir );
		if( structKeyExists( javaConfig, "classPath" ) && hasValue( javaConfig.classPath ) ) withClassPath( javaConfig.classPath );
		if( structKeyExists( javaConfig, "compileOptions" ) && structCount( javaConfig.compileOptions ?: {} ) ) compileOptions( javaConfig.compileOptions );
		if( structKeyExists( javaConfig, "jarOptions" ) && structCount( javaConfig.jarOptions ?: {} ) ) jarOptions( javaConfig.jarOptions );
		if( structKeyExists( javaConfig, "fatJarOptions" ) && structCount( javaConfig.fatJarOptions ?: {} ) ) configureFatJar( javaConfig.fatJarOptions );
		if( structKeyExists( javaConfig, "verbose" ) && isBoolean( javaConfig.verbose ) ) setVerbose( javaConfig.verbose );
		if( structKeyExists( javaConfig, "javaDocs" ) && isBoolean( javaConfig.javaDocs ) ) setUseJavaDoc( javaConfig.javaDocs );
		if( structKeyExists( javaConfig, "jar" ) && isBoolean( javaConfig.jar ) && javaConfig.jar ) {
			toJar( javaConfig.jarName ?: "" );
		}
		if( structKeyExists( javaConfig, "fatJar" ) && isBoolean( javaConfig.fatJar ) && javaConfig.fatJar ) {
			toFatJar( javaConfig.fatJarName ?: "", javaConfig.fatJarJars ?: [] );
		}

		return this;
	}

	/**
	 * Checks whether a string or array value is non-empty.
	 *
	 * @value The value to inspect.
	 * @returns True when the value is a non-empty string or array.
	 */
	private boolean function hasValue( required any value ) {
		if( isSimpleValue( arguments.value ) ) {
			return len( arguments.value ) > 0;
		}
		if( isArray( arguments.value ) ) {
			return arrayLen( arguments.value ) > 0;
		}
		return false;
	}

	/**
	 * Sets the Java source directories, files, globs, or comma-delimited source paths.
	 *
	 * @sourcePaths A source directory, file, glob, comma-delimited string, or array of paths.
	 * @returns The current DSL instance.
	 */
	function fromSource( required any sourcePaths ) {
		if( isSimpleValue( arguments.sourcePaths ) ) {
			arguments.sourcePaths = listToArray( arguments.sourcePaths, ",", true );
		}
		arguments.sourcePaths = arguments.sourcePaths.map( function( s ) {
			return fileSystemutil.resolvePath( arguments.s, getProjectRoot() );
		} );
		variables.sourcePaths = arguments.sourcePaths;
		return this;
	}

	/**
	 * Sets the directory where compiled Java classes are written.
	 *
	 * @classOutputDirectory The class output directory.
	 * @returns The current DSL instance.
	 */
	function toClasses( required classOutputDirectory ){
        setClassOutputDirectory( fileSystemutil.resolvePath( classOutputDirectory, getProjectRoot() ) )
        return this;
    }

	/**
	 * Enables verbose compiler and JAR command output.
	 *
	 * @returns The current DSL instance.
	 */
	function verbose() {
        setVerbose( true );
        return this;
    }

	/**
	 * Enables JAR creation and optionally sets the JAR filename.
	 *
	 * @jarName The output JAR filename.
	 * @returns The current DSL instance.
	 */
	function toJar( string jarName='' ) {
		if( jarName.len() ) {
			setJarNameString( jarName );
		}
		setThinJarRequested( true );
		setCreateJar( true );
		return this;
	}

	/**
	 * Sets the directory where generated JAR files are written.
	 *
	 * @libsDir The directory where generated JAR files are written.
	 * @returns The current DSL instance.
	 */
	function libsDir( required libsDir ) {
		setLibsDir(libsDir);
		return this;
	}

	/**
	 * Configures supported javac compiler options.
	 *
	 * @options A struct of supported javac option names and values.
	 * @returns The current DSL instance.
	 */
	function compileOptions( required struct options ) {
		var supportedOptions = [
			"release", "source", "target", "encoding", "debug", "deprecation", "enablePreview",
			"nowarn", "parameters", "werror", "lint", "maxErrors", "maxWarnings",
			"proc", "implicit", "processors", "processorPath", "sourcePath", "modulePath",
			"addModules", "limitModules", "moduleSourcePath"
		];

		for( var optionName in arguments.options ) {
			if( !supportedOptions.findNoCase( optionName ) ) {
				throw( message="Unsupported compiler option: #optionName#", type="commandException" );
			}
		}

		// Merge with any previously applied options (such as box.json defaults).
		// Later calls win for any keys they both define.
		structAppend( variables.compileOptionsParams, arguments.options, true );
		var options = variables.compileOptionsParams;
		var commandOptions = [];

		if( options.keyExists( "encoding" ) ) {
			setEncode( options.encoding );
		}
		for( var valueOption in [ "release", "source", "target", "proc", "implicit" ] ) {
			if( options.keyExists( valueOption ) ) {
				var optionName = valueOption == "proc" || valueOption == "implicit" ? "-#valueOption#" : "--#valueOption#";
				commandOptions.append( optionName.startsWith( "--" ) ? "#optionName#=#options[valueOption]#" : "#optionName#:#options[valueOption]#" );
			}
		}
		for( var flag in [ "deprecation", "enablePreview", "nowarn", "parameters", "werror" ] ) {
			if( options[ flag ] ?: false ) {
				commandOptions.append( flag == "enablePreview" ? "--enable-preview" : "-#flag#" );
			}
		}
		if( options.keyExists( "debug" ) ) {
			if( isBoolean( options.debug ) && options.debug ) {
				commandOptions.append( "-g" );
			} else if( isArray( options.debug ) ) {
				commandOptions.append( "-g:#options.debug.toList( ',' )#" );
			}
		}
		if( options.keyExists( "lint" ) ) {
			commandOptions.append( "-Xlint:#isArray( options.lint ) ? options.lint.toList( ',' ) : options.lint#" );
		}
		var numericMappings = { "maxErrors" : "-Xmaxerrs", "maxWarnings" : "-Xmaxwarns" };
		for( var numericOption in numericMappings ) {
			if( options.keyExists( numericOption ) ) {
				commandOptions.append( "#numericMappings[numericOption]# #options[numericOption]#" );
			}
		}
		for( var pathOption in [ "processorPath", "sourcePath", "modulePath", "moduleSourcePath" ] ) {
			if( options.keyExists( pathOption ) ) {
				var pathValue = isArray( options[pathOption] ) ? options[pathOption].toList( "," ) : options[pathOption];
				commandOptions.append( "--#pathOption# #pathValue#" );
			}
		}
		for( var moduleOption in [ "addModules", "limitModules" ] ) {
			if( options.keyExists( moduleOption ) ) {
				var moduleValue = isArray( options[moduleOption] ) ? options[moduleOption].toList( "," ) : options[moduleOption];
				commandOptions.append( "--#moduleOption# #moduleValue#" );
			}
		}
		setCompileOptionsString( commandOptions.toList( " " ) );
		return this;
	}

	/**
	 * Configures supported JAR tool options.
	 *
	 * @options A struct of supported JAR option names and values.
	 * @returns The current DSL instance.
	 */
	function jarOptions( required struct options ) {
		var supportedOptions = [ "compress", "mainClass", "date", "moduleVersion", "release", "hashModules", "modulePath", "noManifest" ];
		for( var optionName in arguments.options ) {
			if( !supportedOptions.findNoCase( optionName ) ) {
				throw( message="Unsupported JAR option: #optionName#", type="commandException" );
			}
		}

		// Merge with any previously applied options (such as box.json defaults).
		// Later calls win for any keys they both define.
		structAppend( variables.jarOptionsParams, arguments.options, true );
		var options = variables.jarOptionsParams;
		var modeFlags = "";
		if( options.keyExists( "compress" ) && !options.compress ) {
			modeFlags &= "0";
		}
		if( options.noManifest ?: false ) {
			modeFlags &= "M";
		}
		setJarOptionsString( modeFlags );
		var optionArguments = [];
		var valueMappings = {
			"mainClass" : "--main-class",
			"date" : "--date",
			"moduleVersion" : "--module-version",
			"release" : "--release",
			"hashModules" : "--hash-modules",
			"modulePath" : "--module-path"
		};
		for( var key in valueMappings ) {
			if( options.keyExists( key ) ) {
				var optionName = valueMappings[ key ];
				var optionValue = options[ key ];
				if( key == "date" && isDate( optionValue ) ) {
					optionValue = dateTimeFormat( optionValue, "yyyy-mm-dd'T'HH:nn:ss'Z'" );
				}
				optionArguments.append( optionName & '="' & optionValue & '"' );
			}
		}
		setJarOptionArguments( optionArguments.toList( " " ) );
		return this;
	}

	/**
	 * Adds or overrides manifest attributes for the generated JAR.
	 *
	 * Manifest attributes from box.json's `java.manifest` are applied first, so
	 * values passed here take precedence. Repeated calls merge together.
	 *
	 * @customParams A struct of manifest attribute names and values.
	 * @returns The current DSL instance.
	 */
	function manifest( required struct customParams ) {
		var mergedParams = duplicate( getCustomManifestParams() );
		structAppend( mergedParams, arguments.customParams, true );
		setCustomManifestParams( mergedParams );
		return this;
	}

	/**
	 * Adds one or more resource directories whose contents are added to the generated JAR.
	 *
	 * Roots accumulate in the order they are supplied. When two roots contain the
	 * same entry, the later root wins, matching how dependency JARs are merged.
	 * The first call replaces the default `src/main/resources` root.
	 *
	 * @resourcesPath A resource directory, a comma-delimited list of directories, or an array of directories.
	 * @returns The current DSL instance.
	 */
	function withResources( any resourcesPath ) {
		var newPaths = isArray( arguments.resourcesPath )
			? arguments.resourcesPath
			: listToArray( arguments.resourcesPath, ",", true );

		// The default root is replaced by the first explicit configuration, later calls accumulate
		var knownPaths = getResourcePathConfigured()
			? getResourcePath().listToArray( ",", true )
			: [];

		for( var newPath in newPaths ) {
			if( !isSimpleValue( newPath ) || !len( trim( newPath ) ) || knownPaths.findNoCase( trim( newPath ) ) > 0 ) {
				continue;
			}
			knownPaths.append( trim( newPath ) );
		}

		setResourcePath( knownPaths.toList( "," ) );
		return this;
	}

	/**
	 * Sets the project resource roots, replacing any that were configured before.
	 *
	 * @resourcePath A resource directory or a comma-delimited list of directories.
	 * @returns The current DSL instance.
	 */
	function setResourcePath( required string resourcePath ) {
		variables.resourcePath = arguments.resourcePath;
		variables.resourcePathConfigured = true;
		return this;
	}

	/**
	 * Returns the resolved project resource roots in the order they were supplied.
	 *
	 * @returns Array of absolute resource directory paths.
	 */
	function getResourcePaths() {
		var resourceRoots = [];
		for( var resourcePath in getResourcePath().listToArray( ",", true ) ) {
			if( !len( trim( resourcePath ) ) ) {
				continue;
			}
			var resolvedPath = fileSystemutil.resolvePath( trim( resourcePath ), getProjectRoot() );
			if( resourceRoots.findNoCase( resolvedPath ) == 0 ) {
				resourceRoots.append( resolvedPath );
			}
		}
		return resourceRoots;
	}

	/**
	 * Enables Javadoc generation.
	 *
	 * @returns The current DSL instance.
	 */
	function withJavaDocs(){
		setUseJavaDoc(true);
		return this;
	}

	/**
	 * Sets compiler classpath JARs or directories containing JARs.
	 *
	 * @classPath A JAR, JAR directory, comma-delimited value, or array of paths.
	 * @returns The current DSL instance.
	 */
	function withClassPath( required any classPath ) {
		if( isSimpleValue( arguments.classPath ) ) {
			arguments.classPath = listToArray( arguments.classPath, ",", true );
		}
		arguments.classPath = arguments.classPath.reduce( function( classPaths,cp ) {
			var resolvedPath = fileSystemutil.resolvePath( cp, getProjectRoot() );
			if( fileExists( resolvedPath ) ) {
				return classPaths.append( resolvedPath );
			}
			return classPaths.append(directorylist( resolvedPath, true, 'array', '*jar' ), true);
		}, [] );
		setClassPaths(  arguments.classPath );
		return this;
	}

	/**
	 * Expands JAR paths and directories containing JARs into a flat JAR list.
	 *
	 * @jarPaths JAR file paths and directories that contain JAR files.
	 * @returns The resolved JAR file paths.
	 */
	private array function expandJarPaths( required array jarPaths ) {
		var expandedJars = [];
		for( var jarPath in arguments.jarPaths ) {
			if( !isSimpleValue( jarPath ) || !len( trim( jarPath ) ) ) {
				continue;
			}

			var resolvedPath = fileSystemutil.resolvePath( jarPath, getProjectRoot() );
			if( fileExists( resolvedPath ) ) {
				expandedJars.append( resolvedPath );
				continue;
			}

			if( directoryExists( resolvedPath ) ) {
				var directoryJars = directoryList( resolvedPath, true, "array", "*.jar" ).sort( "textnocase" );
				if( !directoryJars.len() ) {
					throw(
						message="Fat JAR dependency directory contains no JAR files: #resolvedPath#",
						type="commandException"
					);
				}
				expandedJars.append( directoryJars, true );
				continue;
			}

			// Leave missing paths alone so the merge reports them as missing dependencies
			expandedJars.append( resolvedPath );
		}

		return expandedJars;
	}

	/**
	 * Enables JAR creation and merges the supplied dependency JARs.
	 *
	 * @jarName The output fat JAR filename.
	 * @includeJars Dependency JAR paths, directories containing JARs, or a comma-delimited list of either.
	 * @options Fat JAR configuration options.
	 * @returns The current DSL instance.
	 */
	function toFatJar( string jarName='', any includeJars=[], struct options={} ) {
		if( isSimpleValue( arguments.includeJars ) ) {
			arguments.includeJars = listToArray( arguments.includeJars, ",", true );
		}
		arguments.includeJars = expandJarPaths( arguments.includeJars );
		setFatJarPaths( arguments.includeJars );
		if( arguments.jarName.len() ) {
			setFatJarNameString( arguments.jarName );
		}
		if( arguments.options.len() ) {
			configureFatJar( arguments.options );
		}
		setFatJarRequested( true );
		setCreateJar( true );
		return this;
	}

	/**
	 * Configures duplicate, signature, and service-descriptor handling for fat JARs.
	 *
	 * @options Fat JAR options including duplicatePolicy, excludeSignatures, and mergeServiceDescriptors.
	 * @returns The current DSL instance.
	 */
	function configureFatJar( required struct options ) {
		var supportedOptions = [ "mergeServiceDescriptors", "excludeSignatures", "duplicatePolicy" ];
		for( var optionName in arguments.options ) {
			if( !supportedOptions.findNoCase( optionName ) ) {
				throw(
					message="Unsupported fat JAR option: #optionName#",
					type="commandException"
				);
			}
		}

		var mergedOptions = duplicate( getFatJarOptions() );
		structAppend( mergedOptions, arguments.options, true );
		mergedOptions.duplicatePolicy = lCase( mergedOptions.duplicatePolicy );
		if( ![ "last", "first", "error" ].find( mergedOptions.duplicatePolicy ) ) {
			throw(
				message="Invalid fat JAR duplicate policy: #mergedOptions.duplicatePolicy#",
				detail="Supported policies are: last, first, error.",
				type="commandException"
			);
		}
		setFatJarOptions( mergedOptions );
		return this;
	}

	/** Compiles sources and performs the requested JAR or Javadoc operations. */
	struct function run() {
		job.start( 'Compile Task' );

		job.addLog( 'Resolving Java Development Kit.' );
		setJavaBinFolder( findJDKBinDirectory() );

		// Bookend the whole DSL run: listeners/package scripts can generate sources or resources
		announceCompileInterception( 'preJavaCompile', {
			"projectRoot"          : getProjectRoot(),
			"jdkBinDirectory"      : getJavaBinFolder(),
			"sourceDirectory"      : getSourceDirectory(),
			"sourcePaths"          : getSourcePaths(),
			"classOutputDirectory" : fileSystemutil.resolvePath( getClassOutputDirectory(), getProjectRoot() ),
			"classPaths"           : getClassPaths(),
			"compileOptions"       : getCompileOptionsString(),
			"compileOptionsParams" : getCompileOptionsParams(),
			"encoding"             : getEncode(),
			"resourcePaths"        : getResourcePaths(),
			"resourcePath"         : getResourcePath(),
			"libsDir"              : getLibsDir(),
			"jarNameString"        : getJarNameString(),
			"fatJarNameString"     : getFatJarNameString(),
			"fatJarPaths"          : getFatJarPaths(),
			"fatJarOptions"        : getFatJarOptions(),
			"jarOptions"           : getJarOptionsParams(),
			"manifest"             : getCustomManifestParams(),
			"createJar"            : getCreateJar(),
			"useJavaDoc"           : getUseJavaDoc(),
			"verbose"              : getVerbose()
		} );

		job.start( 'Compile Java Sources' );
		compileCode();
		job.complete();

		if( getUseJavaDoc() ) {
			job.start( 'Generate Javadocs' );
			generateJavadocs();
			job.complete();
		}

		if( getCreateJar() ) {
			job.addLog( 'Preparing JAR manifest.' );
			updateManifestFile();

			job.start( 'Build JAR' );
			buildJar();
			job.complete();

			if ( getFatJarRequested() ) {
				job.start( 'Build Fat JAR' );
				buildFatJar();
				job.complete();

				// The thin JAR only seeds the fat JAR merge, it is an output only when it was asked for
				if( !getThinJarRequested() ) {
					removeUnrequestedThinJar();
				}
			} else {
				// Project resources are merged into a fat JAR, a thin JAR still needs them added
				job.addLog( 'Adding JAR resources when available.' );
				moveResources();
			}
		}

		job.complete( getVerbose() );

		var result = {
			"projectRoot"           : getProjectRoot(),
			"jdkBinDirectory"       : getJavaBinFolder(),
			"sourcePaths"           : getSourcePaths(),
			"classOutputDirectory"  : fileSystemutil.resolvePath( getClassOutputDirectory(), getProjectRoot() ),
			"libsDirectory"         : fileSystemutil.resolvePath( getLibsDir(), getProjectRoot() ),
			"jarPath"               : getGeneratedJarPath(),
			"javaDocsPath"          : getUseJavaDoc()
				? fileSystemutil.resolvePath( getJavaDocDestinationDir(), getProjectRoot() )
				: "",
			"resourcePath"          : getResourcePaths().toList( "," ),
			"resourcePaths"         : getResourcePaths(),
			"classPaths"            : getClassPaths(),
			"fatJarPaths"           : getFatJarPaths(),
			"fatJarDependencyCount" : getFatJarPaths().len(),
			"fatJarRequested"       : getFatJarRequested(),
			"compileOptions"        : getCompileOptionsString(),
			"jarOptions"            : getJarOptionsString(),
			"encoding"              : getEncode(),
			"manifest"              : getCustomManifestParams()
		};

		// Listeners get the same struct this method returns, and may add to it
		announceCompileInterception( 'postJavaCompile', result );

		return result;
    }

	/**
	 * Compiles the resolved Java source paths with javac.
	 *
	 * @returns Nothing. Compiled classes are written to the configured output directory.
	 */
	function compileCode() {

		/* if( directoryExists( getClassOutputDirectory() ) ){
			directoryDelete( getClassOutputDirectory(), true )
		} */

		//shell.printString( " glob-> start... " );
        //job.addLog( " glob-> start... " );
		var currentProjectRoot = getProjectRoot();

		var globber = wirebox.getInstance( 'globber' );
		var tempSrcFileName = tempDir & 'temp#createUUID()#.txt';
		/* var tempSrcFileName = currentProjectRoot & 'temp#createUUID()#.txt'; */
		//job.addLog( " " & serialize( getSourcePaths() ) & " " );

		// use only one variable
		if( len( getSourcePaths() ) EQ 1 and getSourcePaths()[1] == "" ) {
			setSourcePaths( [getSourceDirectory()] );
		}

		setSourcePaths( getSourcePaths().map( function( p ) {
			var currentPath = fileSystemutil.resolvePath( arguments.p, getProjectRoot() );
            // check the path if there is one * then assume its globbing and leave it
            // if its not a file then add the **.jav

			if( Find( "*", currentPath ) ) {
				return currentPath;

			} else if( directoryExists( currentPath ) ) {
				currentPath &= "**.java";
				return currentPath;

			}

			return currentPath;

		} ) );

		job.addLog(
			"Compiling source files from: #getSourcePaths().map( function( sourcePath ) {
				return replaceNoCase( sourcePath, getProjectRoot(), "" );
			} ).toList( ', ' )#"
		);
		try{

			writeTempSourceFile( tempSrcFileName );

			var classPathString = "";
			if ( len(getClassPaths()) ) {
				var cpSeparator = fileSystemUtil.isWindows() ? ';' : ':';
				classPathString = '-cp "#getClassPaths().toList( cpSeparator )#"';
			}

			var additionalOptions = "";
			if( getCompileOptionsString().len() ) {
				additionalOptions &= " #getCompileOptionsString()#";
			}
			if( getEncode().len() ) {
				additionalOptions &= " -encoding #getEncode()#";
			}
			if( getVerbose() ) {
				additionalOptions &= " -verbose";
			}
			var classOutputDirectory = reReplace(
				fileSystemutil.normalizeSlashes( variables.classOutputDirectory ),
				"/+$",
				""
			);
			var javacCommand = nativeRunCommand(
				getJavaBinFolder() & "javac",
				'#classPathString# "@#tempSrcFileName#" -d "#classOutputDirectory#"#additionalOptions#'
			);

			if( getVerbose() ) {
				job.addLog( javacCommand );
			}
			runCompileCommand( javacCommand, "Java compilation" );

		} catch( any e ) {
			job.addLog( "Compilation failed: #e.message#" );
			if( len( e.detail ?: "" ) ) {
				job.addLog( e.detail );
			}
			var exceptionInfo = e.extendedInfo ?: "";
			if( isJSON( exceptionInfo ) ) {
				exceptionInfo = deserializeJSON( exceptionInfo );
			}
			if( isStruct( exceptionInfo ) ) {
				if( exceptionInfo.keyExists( "commandOutput" ) && len( exceptionInfo.commandOutput ) ) {
					job.addLog( exceptionInfo.commandOutput );
				}
			}
			throw( message="Compilation failed: #e.message#", detail=e.detail, type="commandException" );
		} finally {
			if ( FileExists( tempSrcFileName ) ) {
				fileDelete( tempSrcFileName );
			}

		}

	}

	/**
	 * Announces a compile lifecycle interception point.
	 *
	 * `preJavaCompile` fires at the start of run() with the DSL arguments, before
	 * anything is compiled; listeners may change any of them. `postJavaCompile`
	 * fires at the end of run() with the exact struct run() returns, so listeners
	 * may add to the result.
	 *
	 * Fired by the DSL (not the `java compile` command) so every consumer of the
	 * DSL gets it, and hooked up to package scripts of the same name via the
	 * PackageScripts interceptor.
	 *
	 * @state The interception point to announce: preJavaCompile or postJavaCompile.
	 * @interceptData The data to announce. The caller supplies it.
	 * @returns The intercept data after listeners ran.
	 */
	private struct function announceCompileInterception( required string state, required struct interceptData ) {
		var data = arguments.interceptData;

		wirebox.getInstance( 'interceptorService' ).announceInterception( arguments.state, data );

		// preJavaCompile listeners can change the inputs before the build uses them
		if( arguments.state == 'preJavaCompile' ) {
			applyCompileInterceptData( data );
		}

		return data;
	}

	/**
	 * Writes changes a preJavaCompile listener made back into the DSL.
	 *
	 * Every announced key is honoured, so a listener can replace any input it was
	 * given. Keys the listener did not touch are written back unchanged.
	 *
	 * @data The intercept data after listeners ran.
	 * @returns Nothing.
	 */
	private function applyCompileInterceptData( required struct data ) {
		var input = arguments.data;

		if( isSimpleValue( input.projectRoot ?: "" ) && input.projectRoot.len() ) {
			setProjectRoot( input.projectRoot );
		}
		if( isSimpleValue( input.jdkBinDirectory ?: "" ) && input.jdkBinDirectory.len() ) {
			setJavaBinFolder( input.jdkBinDirectory );
		}
		if( isSimpleValue( input.sourceDirectory ?: "" ) && input.sourceDirectory.len() ) {
			setSourceDirectory( input.sourceDirectory );
		}
		if( isArray( input.sourcePaths ?: "" ) && input.sourcePaths.len() ) {
			setSourcePaths( input.sourcePaths );
		}
		if( isSimpleValue( input.classOutputDirectory ?: "" ) && input.classOutputDirectory.len() ) {
			setClassOutputDirectory( input.classOutputDirectory );
		}
		if( isArray( input.classPaths ?: "" ) ) {
			setClassPaths( input.classPaths );
		}
		if( isSimpleValue( input.encoding ?: "" ) ) {
			setEncode( input.encoding );
		}
		if( isArray( input.resourcePaths ?: "" ) && serializeJSON( input.resourcePaths ) != serializeJSON( getResourcePaths() ) ) {
			setResourcePath( input.resourcePaths.toList( "," ) );
		} else if( isSimpleValue( input.resourcePath ?: "" ) && input.resourcePath != getResourcePath() ) {
			setResourcePath( input.resourcePath );
		}
		if( isSimpleValue( input.libsDir ?: "" ) && input.libsDir.len() ) {
			setLibsDir( input.libsDir );
		}
		if( structKeyExists( input, "jarNameString" ) ) {
			setJarNameString( input.jarNameString ?: "" );
		}
		if( structKeyExists( input, "fatJarNameString" ) ) {
			setFatJarNameString( input.fatJarNameString ?: "" );
		}
		if( isArray( input.fatJarPaths ?: "" ) ) {
			setFatJarPaths( input.fatJarPaths );
		}
		if( isStruct( input.fatJarOptions ?: "" ) && input.fatJarOptions.len() ) {
			configureFatJar( input.fatJarOptions );
		}
		if( isStruct( input.compileOptionsParams ?: "" ) && serializeJSON( input.compileOptionsParams ) != serializeJSON( getCompileOptionsParams() ) ) {
			compileOptions( input.compileOptionsParams );
		} else if( isSimpleValue( input.compileOptions ?: "" ) && input.compileOptions != getCompileOptionsString() ) {
			setCompileOptionsString( input.compileOptions );
		}
		if( isStruct( input.jarOptions ?: "" ) && serializeJSON( input.jarOptions ) != serializeJSON( getJarOptionsParams() ) ) {
			jarOptions( input.jarOptions );
		} else if( isSimpleValue( input.jarOptionsString ?: "" ) && structKeyExists( input, "jarOptionsString" ) ) {
			setJarOptionsString( input.jarOptionsString );
		}
		if( isStruct( input.manifest ?: "" ) ) {
			setCustomManifestParams( input.manifest );
		}
		if( structKeyExists( input, "createJar" ) ) {
			setCreateJar( isBoolean( input.createJar ) ? input.createJar : false );
		}
		if( structKeyExists( input, "useJavaDoc" ) ) {
			setUseJavaDoc( isBoolean( input.useJavaDoc ) ? input.useJavaDoc : false );
		}
		if( structKeyExists( input, "verbose" ) ) {
			setVerbose( isBoolean( input.verbose ) ? input.verbose : false );
		}
	}

	/**
	 * Writes matching source file paths to a javac response file.
	 *
	 * @tempSrcFileName The response file to write.
	 * @sourcePath The source paths to scan.
	 * @extension The source file extension to include.
	 * @returns Nothing. The response file is written to disk.
	 */
	function writeTempSourceFile( string tempSrcFileName , array sourcePath=getSourcePaths() , string extension=".java" ) {
		var globber = wirebox.getInstance( 'globber' );

		//shell.printString( " gSP-> #serialize(getSourcePaths())# " );
        //job.addLog( " gSP-> #serialize(sourcePath)# " );
		var sourceList = globber
				.setPattern( sourcePath )
				.asQuery()
				.matches()
				.filter(( row ) => row.type=="file" && row.name.endsWith( extension ))
				.reduce(( acc, row ) => {
					return listappend( acc, row.directory & "/" & row.name, chr(10) );
				}, "")

        //job.addLog( " sList-> #serialize(sourceList)# " );
		if( !sourceList.len() ) {
			throw(
				message='No #extension# files found in [#getSourcePaths().toList()#]', detail='Check fromSource() and try again',
				type="commandException"
			);
		}

		fileWrite( tempSrcFileName, sourceList );
	}

	/**
	 * Writes matching compiled class paths to a JAR tool response file.
	 *
	 * @tempSrcFileName The response file to write.
	 * @sourcePath The compiled class paths to scan.
	 * @extension The class file extension to include.
	 * @returns Nothing. The response file is written to disk.
	 */
	function writeTempClassFiles(
		string tempSrcFileName,
		array sourcePath = getSourcePaths(),
		string extension = ".class"
	) {
		var classOutput = reReplace(
			fileSystemutil.normalizeSlashes( fileSystemutil.resolvePath( getClassOutputDirectory(), getProjectRoot() ) ),
			"/+$",
			""
		);
		var globber = wirebox.getInstance( "globber" );
		var entries = globber
			.setPattern( sourcePath )
			.asQuery()
			.matches()
			.filter( ( row ) => compareNoCase( row.type, "file" ) == 0 && row.name.endsWith( extension ) )
			.reduce( ( acc, row ) => {
				var relativeDirectory = replaceNoCase(
					reReplace( fileSystemutil.normalizeSlashes( row.directory ), "/+$", "" ),
					classOutput,
					""
				);
				relativeDirectory = reReplace( relativeDirectory, "^/+", "" );
				var relativePath = relativeDirectory.len() ? relativeDirectory & "/" & row.name : row.name;
				if(
					relativePath.startsWith( "/" )
					|| find( ":", relativePath )
					|| findNoCase( classOutput, relativePath )
				) {
					throw(
						message = "Cannot compute a path for [#relativePath#] relative to classes directory "
							& "[#classOutput#].",
						type = "commandException"
					);
				}
				return listAppend( acc, "-C #classOutput# #relativePath#", chr( 10 ) );
			}, "" );

		if( !entries.len() ) {
			throw(
				message = "No #extension# files found in classes directory [#classOutput#].",
				detail = "Check toClasses() and the compiled output before creating a JAR.",
				type = "commandException"
			);
		}

		fileWrite( tempSrcFileName, entries );
	}

	/**
	 * Creates the configured JAR from compiled classes.
	 *
	 * @returns Nothing. The generated JAR path is stored in the result metadata.
	 */
	function buildJar() {
		var currentLibsDir = reReplace(
			fileSystemutil.normalizeSlashes( fileSystemutil.resolvePath( getLibsDir(), getProjectRoot() ) ),
			"/+$",
			""
		) & "/";
		var jarName = getJarNameString();
        var currentProjectRoot = getProjectRoot();

		var tempClassFileName = tempDir & 'temp#createUUID()#.txt';

        var sourceFolders = [];
		buildJarSourceFolders = reReplace(
			fileSystemutil.normalizeSlashes(
				fileSystemutil.resolvePath( getClassOutputDirectory(), getProjectRoot() )
			),
			"/+$",
			""
		);
		sourceFolders.append( buildJarSourceFolders & "/**.class" );

		//job.addLog( "currLibsDir-> #currentLibsDir#" );

        if( !jarName.len() ){
			jarName = getJarNameFromPackage( currentProjectRoot );

            if( !jarName.len() ) {
                // it is not a package its a normal folder
				var word = '';
				if( ListLen( getProjectRoot(), "\/" ) >= 1 ) {
					word = ListLast( getProjectRoot(), "\/" );

				} else {
					word = "output";

				}
				jarName &= "/" & word & ".jar";

            }

        }

		setJarNameString( jarName );
		var outputJarPath = currentLibsDir & jarName;
		setGeneratedJarPath( outputJarPath );
		//job.addLog( ' jarName= #jarName# ' );
		//job.addLog( ' jarName*= #getJarNameString()# ' );

        try{
            //writeTempSourceFile( tempSrcFileName,['D:\Javatest\greetings\classes\**.class'], ".class" );
            writeTempClassFiles( tempClassFileName, sourceFolders, ".class" );

			if( !directoryExists( currentLibsDir ) ) {
				directoryCreate( currentLibsDir );
			}

            //j = 'run "#getJavaBinFolder()#jar" --file #currentLibsDir##jarName# #getJarOptionsString()#';
            //j = 'run "#getJavaBinFolder()#jar" --create --file #currentLibsDir#testX.jar "@#tempSrcFileName#" #getJarOptionsString()#';
			var jarMode = "c#getJarOptionsString()#f";
			if( getVerbose() ) {
				jarMode &= "v";
			}
			if( getJarOptionArguments().len() ) {
				var jarCommandOptions = "--create --file=" & chr(34) & outputJarPath & chr(34) & " " & getJarOptionArguments();
				if( getJarOptionsString().find( "0" ) ) {
					jarCommandOptions &= " --no-compress";
				}
				if( getJarOptionsString().find( "v" ) ) {
					jarCommandOptions &= " --verbose";
				}
				if( getJarOptionsString().find( "M" ) ) {
					jarCommandOptions &= " --no-manifest";
				}
				if( getVerbose() ) {
					jarCommandOptions &= " --verbose";
				}
				if( getCustomManifest().len() ) {
					jarCommandOptions &= ' --manifest="#variables.customManifest#"';
				}
				j = nativeRunCommand( getJavaBinFolder() & "jar", '#jarCommandOptions# "@#tempClassFileName#"' );
			} else if( !getCustomManifest().len() ) {
				j = nativeRunCommand( getJavaBinFolder() & "jar", '#jarMode# "#outputJarPath#" "@#tempClassFileName#"' );
			} else {
				j = nativeRunCommand( getJavaBinFolder() & "jar", '#jarMode#m #getJarOptionArguments()# "#outputJarPath#" "#variables.customManifest#" "@#tempClassFileName#"' );
			}
			if( getVerbose() ) {
				job.addLog( j );
			}
            //command( j ).run(echo=true);
			runCompileCommand( j, "JAR creation" );
			job.addLog( "Created JAR: #getGeneratedJarPath()#" );

        } finally {
			if( fileExists( tempClassFileName ) ) {
				fileDelete( tempClassFileName );
			}
			if( getGeneratedManifestFile().len() && fileExists( getGeneratedManifestFile() ) ) {
				fileDelete( getGeneratedManifestFile() );
				setGeneratedManifestFile( '' );
			}
        }


	}

	/**
	 * Removes the thin JAR that only existed to seed a fat JAR merge.
	 *
	 * @returns Nothing.
	 */
	private function removeUnrequestedThinJar() {
		var currentLibsDir = reReplace(
			fileSystemutil.normalizeSlashes( fileSystemutil.resolvePath( getLibsDir(), getProjectRoot() ) ),
			"/+$",
			""
		) & "/";
		var thinJarPath = currentLibsDir & getJarNameString();
		if( thinJarPath == getGeneratedJarPath() || !fileExists( thinJarPath ) ) {
			return;
		}

		job.addLog( "Removing intermediate JAR: #thinJarPath#" );
		fileDelete( thinJarPath );
	}

	/**
	 * Adds configured resources to the generated JAR.
	 *
	 * Resources always go into the artifact produced by this run, which is the
	 * fat JAR when one is configured. Every configured root is applied in order,
	 * so a later root wins entries it shares with an earlier one.
	 *
	 * @returns Nothing. Resources are added to the generated JAR when configured.
	 */
	function moveResources() {
		var outputJar = getGeneratedJarPath();
		if( !outputJar.len() ) {
			var currentLibsDir = reReplace(
				fileSystemutil.normalizeSlashes( fileSystemutil.resolvePath( getLibsDir(), getProjectRoot() ) ),
				"/+$",
				""
			) & "/";
			outputJar = currentLibsDir & getJarNameString();
		}

		for( var currentResourcePath in getResourcePaths() ) {
			if( !directoryExists( currentResourcePath ) ) {
				continue;
			}

			job.addLog( "Including resources from: #replaceNoCase( currentResourcePath, getProjectRoot(), "" )#" );
			// have to replicate this command
			// run ""jar" uf "D:\Javatest\new-tests\libs\new-tests.jar" -C "D:\Javatest\gradle-test-resource\src\main\resources\" ."
			j = nativeRunCommand( getJavaBinFolder() & "jar", 'uf "#outputJar#" -C #currentResourcePath# .' );

			//job.addLog( j );
			//command( j ).run(echo=true);
			runCompileCommand( j, "Resource inclusion" );
		}
	}

	/**
	 * Builds a temporary manifest from explicit and package metadata.
	 *
	 * @returns Nothing. The temporary manifest is used during JAR creation.
	 */
	function updateManifestFile() {
		/*
		the original is default
		if we want to send a struct of parameters to the manifest then use
		.manifest({})
		if we want to send parameters in the box.json add a "manifest"
		take the values that exist from the box.json then set the ones in the "manifest"
		like this:
		"manifest" :  {
			"Manifest-Version": "1.0",
			"Main-Class": "foo.bar",
			"random": "attribute"
   		}

		1. check if the project has a box.json (we do that lets just set a flag)
		2. if it is a box.json
			2.1.
		3. if it is not a box.json
			3.1.
		4. independent of 2 or 3 check if we have a struct of values
		5. check if we override the original manifest
		*/

		var createUpdateManifestFile = false;

		// check if there are any params from a struct
		var paramStruct = getCustomManifestParams();
		if( paramStruct.len() ) {
			createUpdateManifestFile = true;
		}

		// check if project root is a package
		var currentProjectRoot = getProjectRoot();
		if( packageService.isPackage( currentProjectRoot ) ) {
			createUpdateManifestFile = true;
			paramStruct = getParamsFromBoxJson( currentProjectRoot, paramStruct );
		}

		if( createUpdateManifestFile ) {
			job.addLog( "Creating JAR manifest." );
			var tempUpdateManifestFileName = tempDir & 'updateManifest#createUUID()#.txt';
			try {
				writeUpdateManifestFile( tempUpdateManifestFileName, paramStruct );
			} finally {
				/*
				if the file was created then we have to save the filename and path
				to use it when creating the jar
				*/
				if( FileExists( tempUpdateManifestFileName ) ) {
					setCustomManifest( tempUpdateManifestFileName );
					setGeneratedManifestFile( tempUpdateManifestFileName );
				}
			}

		}

	}

	/**
	 * Writes manifest attributes to a temporary manifest file.
	 *
	 * @filename The file to write.
	 * @manifestParams The manifest attribute names and values.
	 * @returns Nothing. The manifest file is written to disk.
	 */
	function writeUpdateManifestFile( string filename, struct manifestParams ) {
		//var currentManifestParams = 'foo: bar';
		/* var updManifestOut = createObject( "java", "java.lang.StringBuilder" ).init('');
		var lb = "#chr( 13 )##chr( 10 )#";

		for( var itemKey in manifestParams ) {
			//job.addLog( '#itemKey#: #manifestParams[itemKey]#' );
			updManifestOut.append( '#itemKey#: #manifestParams[itemKey]##lb#' )
		} */

		var manifestNames = createObject( 'java', 'java.util.jar.Attributes$Name' );
		var manifest = createObject( 'java', 'java.util.jar.Manifest' ).init();
		var attributes = manifest.getMainAttributes();

		attributes.put( manifestNames.MANIFEST_VERSION, '3.0' );

		for( var itemKey in manifestParams ) {
			//job.addLog( '#itemKey#: #manifestParams[itemKey]#' );
			attributes.putValue( itemKey, manifestParams[itemKey] );
		}

		try{

			var out = createObject( 'java', 'java.io.FileOutputStream' ).init( fileSystemUtil.getJavaFile( filename ) );
			manifest.write( out );
			//filewrite( filename, updManifestOut.toString() );

		} finally {

			if( !isNull( out ) ) {
				out.close();
			}

		}
	}

	/**
	 * Adds package metadata and optional box.json manifest overrides to manifest attributes.
	 *
	 * @currentFolder The package directory containing box.json.
	 * @manifestParams The manifest attributes to populate and override.
	 * @returns The populated manifest attributes.
	 */
	function getParamsFromBoxJson( string currentFolder, struct manifestParams ) {
		var boxJsonParams = {};
		var boxJSON = packageService.readPackageDescriptor( currentFolder );
		// first check for all the regular info
		// These only fill keys that are not already present so that explicit
		// `.manifest()` calls always take precedence over box.json values.
		if( len( boxJSON.name ) && !manifestParams.keyExists( "Bundle-Name" ) ) {
			manifestParams["Bundle-Name"] = boxJSON.name;
		}
		if( len( boxJSON.slug ) && !manifestParams.keyExists( "Bundle-SymbolicName" ) ) {
			manifestParams["Bundle-SymbolicName"] = boxJSON.slug;
		}
		if( len( boxJSON.version ) && !manifestParams.keyExists( "Bundle-Version" ) ) {
			manifestParams["Bundle-Version"] = boxJSON.version;
		}
		if( len( boxJSON.author ) && !manifestParams.keyExists( "Built-By" ) ) {
			manifestParams["Built-By"] = boxJSON.author;
		}
		if( len( boxJSON.shortDescription ) && !manifestParams.keyExists( "Bundle-Description" ) ) {
			manifestParams["Bundle-Description"] = boxJSON.shortDescription;
		}
		if( len( boxJSON.ProjectURL ) && !manifestParams.keyExists( "Implementation-URL" ) ) {
			manifestParams["Implementation-URL"] = boxJSON.ProjectURL;
		}
		if( len( boxJSON.Documentation ) && !manifestParams.keyExists( "Bundle-DocURL" ) ) {
			manifestParams["Bundle-DocURL"] = boxJSON.Documentation;
		}
		if( structKeyExists( boxJSON, "License" ) && arrayLen( boxJSON.License ) && len( boxJSON.License[1].URL ) && !manifestParams.keyExists( "Bundle-License" ) ) {
			manifestParams["Bundle-License"] = boxJSON.License[1].URL;
		}
		// after check for the manifest portion of the box.json
		// because if the manifest keys override the ones above in the normal box.json
		// The manifest now lives under the `java` object: box.json -> java.manifest
		var boxJSONManifest = {};
		if( isStruct( boxJSON.java ?: {} ) && structKeyExists( boxJSON.java, "manifest" ) && isStruct( boxJSON.java.manifest ?: {} ) ) {
			boxJSONManifest = boxJSON.java.manifest;
		}
		if( structCount( boxJSONManifest ) ) {
			for( var itemKey in boxJSONManifest ) {
				if( !manifestParams.keyExists( itemKey ) ) {
					manifestParams[itemKey] = boxJSONManifest[itemKey];
				}
			}
		}
		return manifestParams;
	}

    /**
	 * Derives a JAR filename from the package slug and version.
	 *
	 * @currentFolder The package directory containing box.json.
	 * @returns The derived JAR filename, or an empty string when unavailable.
	 */
	function getJarNameFromPackage( string currentFolder ){
		//job.addLog( ' jarName is empty ' );
		//job.addLog( ' currentProjectRoot-> #currentFolder# ' );
		jarName = '';

		if( packageService.isPackage( currentFolder ) ) {

			//job.addLog( ' dir is a package ' );
			//job.addLog( ' inside getJarNameFromPackage() ' );
			var boxJSON = packageService.readPackageDescriptor( currentFolder );
			var packageName = "";
			var packageVersion = "";

			if( len( boxJSON.slug ) ) {
				packageName = boxJSON.slug;
				jarName &= packageName;

				if( len( boxJSON.version ) ) {
					packageVersion = boxJSON.version;
					jarName &= "-" & packageVersion;
				}

				jarName &= ".jar"

			}

		}

        return jarName;
    }

	/**
	 * Merges dependency JAR contents into the generated JAR.
	 *
	 * Entries are streamed straight from the dependency archives into the output
	 * archive. One pass indexes the entries so the duplicate policy and the
	 * service descriptor merging can be applied, then one pass copies the
	 * surviving entries. Nothing is expanded to disk and no external JAR tool is
	 * spawned, so the merge is linear in the amount of content being merged and
	 * reports progress for every archive it touches.
	 *
	 * @returns Nothing. Dependency contents are merged according to the configured options.
	 */
	function buildFatJar() {
		var options = getFatJarOptions();
		var currentLibsDir = reReplace(
			fileSystemutil.normalizeSlashes( fileSystemutil.resolvePath( getLibsDir(), getProjectRoot() ) ),
			"/+$",
			""
		) & "/";
		var fatJarName = getFatJarNameString();
		if( !fatJarName.len() ) {
			fatJarName = getJarNameString();
		}
		var thinJarPath = currentLibsDir & getJarNameString();
		var outputJar = currentLibsDir & fatJarName;
		var mergedJarPath = outputJar & ".tmp";

		// No explicit dependency list means "merge whatever the build compiles against"
		if( !getFatJarPaths().len() ) {
			setFatJarPaths( expandJarPaths( getClassPaths() ) );
		}
		var dependencyJars = getFatJarPaths();

		if( !fileExists( thinJarPath ) ) {
			throw(
				message="Fat JAR source JAR does not exist: #thinJarPath#",
				type="commandException"
			);
		}
		for( var dependencyJar in dependencyJars ) {
			if( !fileExists( dependencyJar ) ) {
				throw(
					message="Fat JAR dependency does not exist: #dependencyJar#",
					type="commandException"
				);
			}
		}

		job.addLog( "Fat JAR dependencies: #dependencyJars.len()#" );
		if( !dependencyJars.len() ) {
			job.addWarnLog(
				"No fat JAR dependencies were supplied and the class path is empty; "
				& "the fat JAR will only contain this project's classes and resources."
			);
		}

		job.addLog( "Scanning #getJarNameString()# and #dependencyJars.len()# dependency JAR(s)." );
		setFatJarDuplicateReport( [] );
		var projectResources = getProjectResources();
		var mergePlan = buildFatJarMergePlan( thinJarPath, dependencyJars, options, projectResources );

		setFatJarDuplicateReport( mergePlan.duplicates );
		if( mergePlan.duplicates.len() ) {
			job.addLog(
				"Resolved #mergePlan.duplicates.len()# duplicate entries using the '#options.duplicatePolicy#' duplicate policy."
			);
		}

		job.addLog( "Writing #mergePlan.entryCount# entries into #fatJarName#." );
		try {
			writeFatJarArchive( mergedJarPath, mergePlan, options );
			moveIntoPlace( mergedJarPath, outputJar );
		} finally {
			if( fileExists( mergedJarPath ) ) {
				fileDelete( mergedJarPath );
			}
		}

		job.addLog( "Created Fat JAR: #outputJar# (#getJarSizeLabel( outputJar )#)." );
		setGeneratedJarPath( outputJar );
	}

	/**
	 * Indexes the project JAR, the project resources, and every dependency so the
	 * duplicate policy and the service descriptor merging can be applied before a
	 * single byte is written.
	 *
	 * @thinJarPath The project JAR the fat JAR starts from.
	 * @dependencyJars The dependency JARs in the order they must be applied.
	 * @options The configured fat JAR options.
	 * @projectResources The project resource root and files applied after the dependencies.
	 * @returns The merge plan holding the winning source for every entry.
	 */
	private struct function buildFatJarMergePlan(
		required string thinJarPath,
		required array dependencyJars,
		required struct options,
		required struct projectResources
	) {
		var plan = {
			"thinJarPath"    : arguments.thinJarPath,
			"manifestEntry"  : "",
			"services"       : [],
			"sources"        : [],
			"winningSources" : {},
			"duplicates"     : [],
			"entryCount"     : 0
		};
		var serviceIndex = {};
		var mergedDependencyEntries = {};

		// The project JAR provides the base entries, including the manifest
		var thinJar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.thinJarPath );
		try {
			var thinEntries = [];
			var thinJarEntries = thinJar.entries();
			while( thinJarEntries.hasMoreElements() ) {
				var thinEntry = thinJarEntries.nextElement();
				if( thinEntry.isDirectory() ) {
					continue;
				}
				var thinEntryName = thinEntry.getName();
				if( thinEntryName.equalsIgnoreCase( "META-INF/MANIFEST.MF" ) ) {
					plan.manifestEntry = thinEntryName;
					continue;
				}
				// A JarIndex describes the archive it was written for and never the merged result
				if( thinEntryName.equalsIgnoreCase( "META-INF/INDEX.LIST" ) ) {
					if( getVerbose() ) {
						job.addLog( "Skipping [META-INF/INDEX.LIST] from #getFileFromPath( arguments.thinJarPath )#." );
					}
					continue;
				}
				plan.winningSources[ thinEntryName ] = arguments.thinJarPath;
				thinEntries.append( thinEntryName );
			}
			plan.sources.append( { "type" : "jar", "path" : arguments.thinJarPath, "entryNames" : thinEntries } );
		} finally {
			thinJar.close();
		}

		var dependencyNumber = 0;
		for( var dependencyJar in arguments.dependencyJars ) {
			dependencyNumber++;
			var dependencyEntries = [];
			var dependencyJarFile = createObject( "java", "java.util.jar.JarFile" ).init( dependencyJar );
			try {
				var jarEntries = dependencyJarFile.entries();
				while( jarEntries.hasMoreElements() ) {
					var entry = jarEntries.nextElement();
					if( entry.isDirectory() ) {
						continue;
					}
					var entryName = entry.getName();
					// The project manifest wins, dependency manifests never ship
					if( entryName.equalsIgnoreCase( "META-INF/MANIFEST.MF" ) ) {
						continue;
					}
					// JarIndex data from a dependency only describes that dependency's layout
					if( entryName.equalsIgnoreCase( "META-INF/INDEX.LIST" ) ) {
						if( getVerbose() ) {
							job.addLog( "Skipping [META-INF/INDEX.LIST] from #getFileFromPath( dependencyJar )#." );
						}
						continue;
					}
					if( arguments.options.excludeSignatures && isJarSignatureEntry( entryName ) ) {
						continue;
					}
					if(
						arguments.options.mergeServiceDescriptors
						&& entryName.startsWith( "META-INF/services/" )
					) {
						if( !serviceIndex.keyExists( entryName ) ) {
							serviceIndex[ entryName ] = { "name" : entryName, "sourceJars" : [], "resourceFiles" : [] };
							plan.services.append( serviceIndex[ entryName ] );
						}
						serviceIndex[ entryName ].sourceJars.append( dependencyJar );
						continue;
					}

					if( mergedDependencyEntries.keyExists( entryName ) ) {
						var previousSource = plan.winningSources[ entryName ];
						if( arguments.options.duplicatePolicy == "first" ) {
							recordDuplicateResolution( plan, entryName, "first", previousSource, dependencyJar );
							continue;
						}
						if( arguments.options.duplicatePolicy == "error" ) {
							throw(
								message="Duplicate fat JAR entry: #entryName#",
								type="commandException"
							);
						}
						recordDuplicateResolution( plan, entryName, "last", dependencyJar, previousSource );
					} else {
						mergedDependencyEntries[ entryName ] = true;
					}

					plan.winningSources[ entryName ] = dependencyJar;
					dependencyEntries.append( entryName );
				}
			} finally {
				dependencyJarFile.close();
			}

			plan.sources.append( { "type" : "jar", "path" : dependencyJar, "entryNames" : dependencyEntries } );
			job.addLog(
				"Scanned [#dependencyNumber#/#arguments.dependencyJars.len()#] #getFileFromPath( dependencyJar )# (#dependencyEntries.len()# entries)"
			);
		}

		// Project resources are applied last: they win regular entries, but their service
		// descriptors are merged with the ones the project JAR and the dependencies ship so
		// no provider is silently dropped.
		if( arguments.projectResources.entries.len() ) {
			var resourceSourceKey = getProjectResourceSourceKey();
			var resourceEntries = [];
			for( var resource in arguments.projectResources.entries ) {
				if(
					arguments.options.mergeServiceDescriptors
					&& resource.entryName.startsWith( "META-INF/services/" )
				) {
					if( !serviceIndex.keyExists( resource.entryName ) ) {
						serviceIndex[ resource.entryName ] = {
							"name"          : resource.entryName,
							"sourceJars"    : [],
							"resourceFiles" : []
						};
						plan.services.append( serviceIndex[ resource.entryName ] );
					}
					serviceIndex[ resource.entryName ].resourceFiles.append( resource.filePath );
					continue;
				}

				plan.winningSources[ resource.entryName ] = resourceSourceKey;
				resourceEntries.append( resource );
			}

			plan.sources.append( {
				"type"    : "files",
				"path"    : resourceSourceKey,
				"entries" : resourceEntries
			} );
			job.addLog( "Added #resourceEntries.len()# project resource file(s) to the merge." );
		}

		plan.entryCount = structCount( plan.winningSources ) + plan.services.len();
		return plan;
	}

	/**
	 * Returns the merge plan key that marks entries supplied by the project resources.
	 *
	 * @returns A value that cannot collide with a JAR or file path.
	 */
	private string function getProjectResourceSourceKey() {
		return "__project_resources__";
	}

	/**
	 * Lists the project resource files that belong in the generated JAR.
	 *
	 * Every configured root is walked in order and merged under one namespace. An
	 * entry that appears in more than one root resolves to the later root, while
	 * the first occurrence decides the write order.
	 *
	 * @returns A struct with the resolved roots and the entry/file pairs.
	 */
	private struct function getProjectResources() {
		var projectResources = { "roots" : [], "entries" : [] };
		var entriesByName = {};
		var entryNames = [];

		for( var resourceRoot in getResourcePaths() ) {
			projectResources.roots.append( resourceRoot );
			if( !directoryExists( resourceRoot ) ) {
				continue;
			}

			job.addLog( "Including resources from: #replaceNoCase( resourceRoot, getProjectRoot(), "" )#" );
			var normalizedRoot = fileSystemutil.normalizeSlashes( resourceRoot );
			for( var filePath in directoryList( resourceRoot, true, "array" ) ) {
				if( !fileExists( filePath ) ) {
					continue;
				}

				var entryName = reReplace(
					replaceNoCase( fileSystemutil.normalizeSlashes( filePath ), normalizedRoot, "" ),
					"^/+",
					""
				);
				if( !entryName.len() ) {
					continue;
				}

				if( !entriesByName.keyExists( entryName ) ) {
					entryNames.append( entryName );
				}
				// A later root wins entries it shares with an earlier one
				entriesByName[ entryName ] = { "entryName" : entryName, "filePath" : filePath };
			}
		}

		for( var entryName in entryNames ) {
			projectResources.entries.append( entriesByName[ entryName ] );
		}

		return projectResources;
	}

	/**
	 * Records a duplicate entry resolved by the duplicate policy and reports it
	 * when verbose output is enabled.
	 *
	 * @plan The merge plan being built.
	 * @entryName The duplicated archive entry.
	 * @duplicatePolicy The policy that resolved the duplicate.
	 * @keptJar The dependency JAR that supplies the entry in the merged archive.
	 * @skippedJar The dependency JAR whose copy of the entry is dropped.
	 * @returns Nothing.
	 */
	private function recordDuplicateResolution(
		required struct plan,
		required string entryName,
		required string duplicatePolicy,
		required string keptJar,
		required string skippedJar
	) {
		arguments.plan.duplicates.append( {
			"entry"      : arguments.entryName,
			"policy"     : arguments.duplicatePolicy,
			"keptJar"    : arguments.keptJar,
			"skippedJar" : arguments.skippedJar
		} );

		// Keep verbose output readable when a merge resolves a very large number of duplicates
		if( !getVerbose() || arguments.plan.duplicates.len() > 100 ) {
			return;
		}

		job.addLog(
			"Duplicate entry [#arguments.entryName#] resolved by policy [#arguments.duplicatePolicy#]: "
			& "keeping [#getFileFromPath( arguments.keptJar )#], skipping [#getFileFromPath( arguments.skippedJar )#]"
		);
	}

	/**
	 * Checks whether an archive entry is a JAR signature file.
	 *
	 * @entryName The archive entry name.
	 * @returns True when the entry is a signature file under META-INF.
	 */
	private boolean function isJarSignatureEntry( required string entryName ) {
		return reFindNoCase( "^META-INF/.*\.(SF|RSA|DSA)$", arguments.entryName ) > 0;
	}

	/**
	 * Writes the merged archive from a merge plan.
	 *
	 * @jarPath The archive file to write.
	 * @mergePlan The plan produced by buildFatJarMergePlan().
	 * @options The configured fat JAR options.
	 * @returns Nothing.
	 */
	private function writeFatJarArchive( required string jarPath, required struct mergePlan, required struct options ) {
		var storeEntries = getJarOptionsString().find( "0" ) > 0;
		var writeManifestEntry = arguments.mergePlan.manifestEntry.len() && !getJarOptionsString().find( "M" );
		var writtenDirectories = {};
		var jarOut = createObject( "java", "java.util.jar.JarOutputStream" ).init(
			createObject( "java", "java.io.BufferedOutputStream" ).init(
				createObject( "java", "java.io.FileOutputStream" ).init( arguments.jarPath )
			)
		);

		try {
			if( writeManifestEntry ) {
				var thinJar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.mergePlan.thinJarPath );
				try {
					writeJarEntry(
						jarOut,
						thinJar,
						thinJar.getJarEntry( arguments.mergePlan.manifestEntry ),
						arguments.mergePlan.manifestEntry,
						storeEntries,
						writtenDirectories
					);
				} finally {
					thinJar.close();
				}
			}

			for( var service in arguments.mergePlan.services ) {
				writeJarEntryContent(
					jarOut,
					service.name,
					buildMergedServiceContent( arguments.mergePlan.thinJarPath, service ),
					storeEntries,
					writtenDirectories
				);
			}

			var sourceNumber = 0;
			for( var source in arguments.mergePlan.sources ) {
				sourceNumber++;
				var writtenEntryCount = 0;
				var writtenEntries = {};

				if( source.type == "jar" ) {
					var sourceJarFile = createObject( "java", "java.util.jar.JarFile" ).init( source.path );
					try {
						for( var entryName in source.entryNames ) {
							// A later source may have won this entry, only its winner writes it
							if(
								arguments.mergePlan.winningSources[ entryName ] != source.path
								|| writtenEntries.keyExists( entryName )
							) {
								continue;
							}
							var sourceEntry = sourceJarFile.getJarEntry( entryName );
							if( isNull( sourceEntry ) ) {
								continue;
							}
							writtenEntryCount++;
							writtenEntries[ entryName ] = true;
							writeJarEntry( jarOut, sourceJarFile, sourceEntry, entryName, storeEntries, writtenDirectories );
						}
					} finally {
						sourceJarFile.close();
					}
				} else {
					for( var resourceEntry in source.entries ) {
						if(
							arguments.mergePlan.winningSources[ resourceEntry.entryName ] != source.path
							|| writtenEntries.keyExists( resourceEntry.entryName )
						) {
							continue;
						}
						writtenEntryCount++;
						writtenEntries[ resourceEntry.entryName ] = true;
						writeResourceFile(
							jarOut,
							resourceEntry.filePath,
							resourceEntry.entryName,
							storeEntries,
							writtenDirectories
						);
					}
				}

				job.addLog(
					"Wrote [#sourceNumber#/#arguments.mergePlan.sources.len()#] #getFileFromPath( source.path )# (#writtenEntryCount# entries)"
				);
			}
		} finally {
			jarOut.close();
		}
	}

	/**
	 * Copies one entry from a source archive into the output archive.
	 *
	 * @jarOut The archive being written.
	 * @sourceJar The open source archive.
	 * @sourceEntry The entry to copy.
	 * @entryName The entry name to write.
	 * @storeEntry True to write the entry without compression.
	 * @writtenDirectories The directory entries already written to the output.
	 * @returns Nothing.
	 */
	private function writeJarEntry(
		required any jarOut,
		required any sourceJar,
		required any sourceEntry,
		required string entryName,
		required boolean storeEntry,
		required struct writtenDirectories
	) {
		writeParentDirectoryEntries(
			arguments.jarOut,
			arguments.entryName,
			arguments.storeEntry,
			arguments.writtenDirectories
		);

		var newEntry = createObject( "java", "java.util.jar.JarEntry" ).init( arguments.entryName );
		if( arguments.sourceEntry.getTime() > 0 ) {
			newEntry.setTime( javaCast( "long", arguments.sourceEntry.getTime() ) );
		}
		if( arguments.storeEntry ) {
			newEntry.setMethod( createObject( "java", "java.util.zip.ZipEntry" ).STORED );
			newEntry.setSize( javaCast( "long", arguments.sourceEntry.getSize() ) );
			newEntry.setCrc( javaCast( "long", arguments.sourceEntry.getCrc() ) );
		}

		arguments.jarOut.putNextEntry( newEntry );
		var inputStream = arguments.sourceJar.getInputStream( arguments.sourceEntry );
		try {
			inputStream.transferTo( arguments.jarOut );
		} finally {
			inputStream.close();
		}
		arguments.jarOut.closeEntry();
	}

	/**
	 * Writes a generated entry into the output archive.
	 *
	 * @jarOut The archive being written.
	 * @entryName The entry name to write.
	 * @content The entry content.
	 * @storeEntry True to write the entry without compression.
	 * @writtenDirectories The directory entries already written to the output.
	 * @returns Nothing.
	 */
	private function writeJarEntryContent(
		required any jarOut,
		required string entryName,
		required string content,
		required boolean storeEntry,
		required struct writtenDirectories
	) {
		writeParentDirectoryEntries(
			arguments.jarOut,
			arguments.entryName,
			arguments.storeEntry,
			arguments.writtenDirectories
		);

		var contentBytes = createObject( "java", "java.lang.String" ).init( arguments.content ).getBytes( "UTF-8" );
		var newEntry = createObject( "java", "java.util.jar.JarEntry" ).init( arguments.entryName );
		if( arguments.storeEntry ) {
			var crc = createObject( "java", "java.util.zip.CRC32" ).init();
			crc.update( contentBytes );
			newEntry.setMethod( createObject( "java", "java.util.zip.ZipEntry" ).STORED );
			newEntry.setSize( javaCast( "long", contentBytes.length ) );
			newEntry.setCrc( crc.getValue() );
		}

		arguments.jarOut.putNextEntry( newEntry );
		arguments.jarOut.write( contentBytes );
		arguments.jarOut.closeEntry();
	}

	/**
	 * Writes a project resource file into the output archive.
	 *
	 * @jarOut The archive being written.
	 * @filePath The resource file to read.
	 * @entryName The entry name to write.
	 * @storeEntry True to write the entry without compression.
	 * @writtenDirectories The directory entries already written to the output.
	 * @returns Nothing.
	 */
	private function writeResourceFile(
		required any jarOut,
		required string filePath,
		required string entryName,
		required boolean storeEntry,
		required struct writtenDirectories
	) {
		if( !fileExists( arguments.filePath ) ) {
			return;
		}

		writeParentDirectoryEntries(
			arguments.jarOut,
			arguments.entryName,
			arguments.storeEntry,
			arguments.writtenDirectories
		);

		var inputStream = createObject( "java", "java.io.FileInputStream" ).init( arguments.filePath );
		try {
			var newEntry = createObject( "java", "java.util.jar.JarEntry" ).init( arguments.entryName );
			if( arguments.storeEntry ) {
				var contentBytes = readStreamBytes( inputStream );
				var crc = createObject( "java", "java.util.zip.CRC32" ).init();
				crc.update( contentBytes );
				newEntry.setMethod( createObject( "java", "java.util.zip.ZipEntry" ).STORED );
				newEntry.setSize( javaCast( "long", contentBytes.length ) );
				newEntry.setCrc( crc.getValue() );
				arguments.jarOut.putNextEntry( newEntry );
				arguments.jarOut.write( contentBytes );
				arguments.jarOut.closeEntry();
				return;
			}

			arguments.jarOut.putNextEntry( newEntry );
			inputStream.transferTo( arguments.jarOut );
			arguments.jarOut.closeEntry();
		} finally {
			inputStream.close();
		}
	}

	/**
	 * Reads a stream into a byte array.
	 *
	 * @inputStream The stream to read.
	 * @returns The stream contents as a byte array.
	 */
	private any function readStreamBytes( required any inputStream ) {
		var outputStream = createObject( "java", "java.io.ByteArrayOutputStream" ).init();
		arguments.inputStream.transferTo( outputStream );
		return outputStream.toByteArray();
	}

	/**
	 * Writes the directory entries a file entry needs before the file itself.
	 *
	 * @jarOut The archive being written.
	 * @entryName The file entry name.
	 * @storeEntry True to write the entries without compression.
	 * @writtenDirectories The directory entries already written to the output.
	 * @returns Nothing.
	 */
	private function writeParentDirectoryEntries(
		required any jarOut,
		required string entryName,
		required boolean storeEntry,
		required struct writtenDirectories
	) {
		var pathParts = arguments.entryName.listToArray( "/" );
		if( pathParts.len() < 2 ) {
			return;
		}

		var directoryName = "";
		for( var i = 1; i < pathParts.len(); i++ ) {
			directoryName &= pathParts[ i ] & "/";
			if( arguments.writtenDirectories.keyExists( directoryName ) ) {
				continue;
			}

			var directoryEntry = createObject( "java", "java.util.zip.ZipEntry" ).init( directoryName );
			if( arguments.storeEntry ) {
				directoryEntry.setMethod( createObject( "java", "java.util.zip.ZipEntry" ).STORED );
				directoryEntry.setSize( 0 );
				directoryEntry.setCrc( 0 );
			}
			arguments.jarOut.putNextEntry( directoryEntry );
			arguments.jarOut.closeEntry();
			arguments.writtenDirectories[ directoryName ] = true;
		}
	}

	/**
	 * Combines the service provider lines from the project JAR, the project
	 * resources, and every dependency that ships the same descriptor.
	 *
	 * Duplicate providers are dropped while the first occurrence keeps its place,
	 * so the project and a dependency can both register providers in one file.
	 *
	 * @thinJarPath The project JAR path.
	 * @service The service descriptor being merged.
	 * @returns The merged provider list, one provider per line.
	 */
	private string function buildMergedServiceContent( required string thinJarPath, required struct service ) {
		var providers = [];
		providers.append( readJarEntryLines( arguments.thinJarPath, arguments.service.name ), true );
		for( var sourceJarPath in arguments.service.sourceJars ) {
			providers.append( readJarEntryLines( sourceJarPath, arguments.service.name ), true );
		}
		for( var resourceFile in arguments.service.resourceFiles ) {
			if( fileExists( resourceFile ) ) {
				providers.append( fileRead( resourceFile ).listToArray( chr( 10 ), true ), true );
			}
		}

		var seenProviders = {};
		var mergedProviders = [];
		for( var provider in providers ) {
			var trimmedProvider = trim( provider );
			if( !trimmedProvider.len() || seenProviders.keyExists( trimmedProvider ) ) {
				continue;
			}
			seenProviders[ trimmedProvider ] = true;
			mergedProviders.append( trimmedProvider );
		}

		return mergedProviders.toList( chr( 10 ) );
	}

	/**
	 * Reads an archive entry as a list of lines.
	 *
	 * @jarPath The archive to read.
	 * @entryName The entry to read.
	 * @returns The entry lines, or an empty array when the entry is missing.
	 */
	private array function readJarEntryLines( required string jarPath, required string entryName ) {
		var jarFile = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarPath );
		try {
			var entry = jarFile.getJarEntry( arguments.entryName );
			if( isNull( entry ) ) {
				return [];
			}
			var inputStream = jarFile.getInputStream( entry );
			try {
				var outputStream = createObject( "java", "java.io.ByteArrayOutputStream" ).init();
				inputStream.transferTo( outputStream );
				return createObject( "java", "java.lang.String" )
					.init( outputStream.toByteArray(), "UTF-8" )
					.listToArray( chr( 10 ), true );
			} finally {
				inputStream.close();
			}
		} finally {
			jarFile.close();
		}
	}
	/**
	 * Replaces a file with a completed one without ever leaving the destination
	 * missing, so an interrupted merge cannot destroy the previous JAR.
	 *
	 * @sourcePath The fully written replacement file.
	 * @destinationPath The file to replace.
	 * @returns Nothing.
	 */
	private function moveIntoPlace( required string sourcePath, required string destinationPath ) {
		var files = createObject( "java", "java.nio.file.Files" );
		var copyOption = createObject( "java", "java.nio.file.StandardCopyOption" );
		var source = createObject( "java", "java.io.File" ).init( arguments.sourcePath ).toPath();
		var destination = createObject( "java", "java.io.File" ).init( arguments.destinationPath ).toPath();

		try {
			files.move( source, destination, [ copyOption.ATOMIC_MOVE, copyOption.REPLACE_EXISTING ] );
			return;
		} catch( any e ) {
			// Not every file system supports atomic renames, a plain replace still never leaves the target missing
		}

		try {
			files.move( source, destination, [ copyOption.REPLACE_EXISTING ] );
			return;
		} catch( any e ) {
			// Fall back to the platform file helpers when NIO cannot move the file
			if( fileExists( arguments.destinationPath ) ) {
				fileDelete( arguments.destinationPath );
			}
			fileMove( arguments.sourcePath, arguments.destinationPath );
		}
	}

	/**
	 * Formats a JAR file size for job output.
	 *
	 * @jarPath The JAR file to measure.
	 * @returns A human readable size such as `1.8 MB`.
	 */
	private string function getJarSizeLabel( required string jarPath ) {
		if( !fileExists( arguments.jarPath ) ) {
			return "missing";
		}

		var sizeInBytes = getFileInfo( arguments.jarPath ).size;
		if( sizeInBytes < 1024 ) {
			return "#sizeInBytes# bytes";
		}
		if( sizeInBytes < 1024 * 1024 ) {
			return "#numberFormat( sizeInBytes / 1024, "0.0" )# KB";
		}
		return "#numberFormat( sizeInBytes / 1024 / 1024, "0.0" )# MB";
	}

	/**
	 * Run another command by DSL.
	 * @name The name of the command to run.
 	 **/
	/**
	 * Creates a Command DSL instance for an internal shell command.
	 *
	 * @name The command name or command line to execute.
	 * @returns CommandDSL The command DSL instance.
	 */
	function command( required name ) {
		return wirebox.getinstance( name='CommandDSL', initArguments={ name : arguments.name } );
	}

	/**
	 * Runs an internal command, logs output, and reports failures with command context.
	 *
	 * @commandLine The command line to execute.
	 * @operation The human-readable operation name used in errors.
	 * @returns The captured command output.
	 */
	private string function nativeRunCommand( required string executable, required string argumentsString ) {
		if( fileSystemUtil.isWindows() ) {
			return '""#arguments.executable#" ' & arguments.argumentsString & '"';
		}
		return '"#arguments.executable#" ' & arguments.argumentsString;
	}

	private any function runCompileCommand(
		required string commandLine,
		required string operation
	) {
		try {
			var commandOutput = wirebox
				.getInstance( name="CommandDSL", initArguments={ "name" : "run" } )
				.params( arguments.commandLine )
				.run( returnOutput=true );
			if( len( commandOutput ?: "" ) ) {
				job.addLog( commandOutput );
			}
			return commandOutput;
		} catch( any e ) {
			var exceptionInfo = e.extendedInfo ?: "";
			if( isJSON( exceptionInfo ) ) {
				exceptionInfo = deserializeJSON( exceptionInfo );
			}
			if( isStruct( exceptionInfo ) && exceptionInfo.keyExists( "commandOutput" ) ) {
				if( len( exceptionInfo.commandOutput ?: "" ) ) {
					job.addLog( exceptionInfo.commandOutput );
				}
			}
			throw(
				message="#arguments.operation# failed: #e.message#",
				detail=e.detail,
				type="commandException",
				extendedInfo=e.extendedInfo ?: ""
			);
		}
	}

	/**
	 * Finds or installs a JDK and returns its bin directory.
	 *
	 * @returns The absolute JDK bin directory path.
	 */
	string function findJDKBinDirectory() {
		var OSExecSuffix = '';
		var OSPathSearch = 'which';

		if( fileSystemUtil.isWindows() ) {
			OSExecSuffix = '.exe';
			OSPathSearch = 'where';
		}

		// First attempt: See if CommandBox CLI is using a JDK to run
		var CLIBinPath = getDirectoryFromPath( fileSystemUtil.getJREExecutable() );

		if( fileExists( CLIBinPath & 'javac' & OSExecSuffix ) && isJDKCompatible( CLIBinPath ) ) {
			job.addLog( 'Using JDK from CommandBox: #CLIBinPath#' );
			return CLIBinPath;
		}

		// Second attempt: Check and see if the OS path has a JDK
		try {
			var OSBinPath = runCompileCommand( OSPathSearch & ' javac', "JDK lookup" ).listToArray( chr(13)&chr(10) ).first()
			OSBinPath = getDirectoryFromPath( OSBinPath );
			if( isJDKCompatible( OSBinPath ) ) {
				job.addLog( 'Using JDK from the OS path: #OSBinPath#' );
				return OSBinPath;
			}
		} catch( any var e ) {
			// Error is raised if binary is not found on path
		}

		// Third attempt: Look at all of the installed Server JREs and see if there is a JDK laying around
		var javaEndpoint = endpointService.getEndpoint( 'java' );
		var installedJREs = javaService.listJavaInstalls();
		for( var installID in installedJREs ) {
			var javaInstall = installedJREs[ installID ];
			var javaDetails = javaEndpoint.parseDetails( javaInstall.packageVersion );

			// If it's not a JDK or is not installed, NEXT!
			if( javaDetails.type != 'jdk' || !javaInstall.isInstalled ) {
				continue;
			}

			// Check just to make sure the JDK actually is for the current OS
			if(
				( fileSystemUtil.isWindows() && javaDetails.os != 'windows' )
				|| ( fileSystemUtil.isLinux() && javaDetails.os != 'linux' )
				|| ( fileSystemUtil.isMac() && javaDetails.os != 'mac' )
			 ) {
				continue;
			}

			var installedJDKVersion = val( replaceNoCase( javaDetails.version, 'openjdk', '' ) );
			if( installedJDKVersion < getRequiredJDKVersion() ) {
				continue;
			}

			var installedJDKBinPath = javaInstall.directory.listAppend( installID, '/' ) & '/bin/';
			job.addLog( 'Using pre-downloaded JDK: #installedJDKBinPath#' );
			return installedJDKBinPath;
		}

		// Fourth attempt: Install something to use:
		var requiredJDKVersion = getRequiredJDKVersion();
		var downloadJDKVersion = requiredJDKVersion > 0 ? requiredJDKVersion : 21;
		job.addLog( 'Compatible JDK not found, let''s download Java #downloadJDKVersion#!' );
		var javaHome = javaService.getJavaInstallPath( 'openjdk#downloadJDKVersion#_jdk', getVerbose() );
		var downloadedJDKBinPath = javaHome.listAppend( 'bin/', '/' );
		job.addLog( 'Using downloaded JDK: #downloadedJDKBinPath#' );
		return downloadedJDKBinPath;
	}

	/**
	 * Returns the minimum JDK version needed by this compile task. A zero return
	 * value means that any available JDK can be used. Java 21 is only used when
	 * a fallback JDK must be downloaded.
	 */
	private numeric function getRequiredJDKVersion() {
		var requiredVersion = 0;
		var compileOptions = getCompileOptionsString();
		var optionMatches = reMatch( "--(?:release|source|target)=(\\d+)", compileOptions );

		for( var optionMatch in optionMatches ) {
			requiredVersion = max( requiredVersion, val( reReplace( optionMatch, "^.*=", "" ) ) );
		}

		return requiredVersion;
	}

	/**
	 * Checks whether a JDK is new enough for this compile task.
	 */
	private boolean function isJDKCompatible( required string binPath ) {
		try {
			var executableSuffix = fileSystemUtil.isWindows() ? '.exe' : '';
			var versionOutput = runCompileCommand(
				nativeRunCommand( arguments.binPath & 'javac' & executableSuffix, '-version' ),
				'JDK version lookup'
			);
			var versionNumber = reReplace( versionOutput, '(?s).*?(?:javac|java) ([0-9]+).*', '\1' );
			return isNumeric( versionNumber ) && val( versionNumber ) >= getRequiredJDKVersion();
		} catch( any e ) {
			return false;
		}
	}

	/**
	 * Generates Javadocs for the resolved Java source paths.
	 *
	 * @returns Nothing. Javadocs are written to the configured destination directory.
	 */
	function generateJavadocs() {
		var javaDocFinalDestinationFolder = fileSystemutil.resolvePath(
			getJavaDocDestinationDir(),
			getProjectRoot()
		);
		var tempSourceFileName = tempDir & 'javadocs#createUUID()#.txt';

		try {
			writeTempSourceFile( tempSourceFileName );
			var j = nativeRunCommand( getJavaBinFolder() & "javadoc", '"@#tempSourceFileName#" -d #javaDocFinalDestinationFolder#' );
			if( getVerbose() ) {
				job.addLog( j );
			}
			runCompileCommand( j, "Javadoc generation" );
			job.addLog( "Generated Javadocs: #javaDocFinalDestinationFolder#" );

		} catch( any e ) {

			if ( isJSON( e.extendedInfo ) ){
				job.addLog( deserializeJSON( e.extendedInfo ).commandOutput );
			}

			throw(
				message='Javadoc found errors', detail=e.message,
				type="commandException"
			);

		} finally {
			if( fileExists( tempSourceFileName ) ) {
				fileDelete( tempSourceFileName );
			}
		}
	}

}
