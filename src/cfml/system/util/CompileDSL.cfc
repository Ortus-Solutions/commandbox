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
	property name='classTextFilePaths'		type='array';
	property name='fatJarPaths'				type='array';
	property name='fatJarOptions'			type='struct';
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
		setClassTextFilePaths(['']);
		setFatJarPaths( [] );
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
	 * Sets the resource directory whose contents are added to the generated JAR.
	 *
	 * @resourcesPath The resource directory path.
	 * @returns The current DSL instance.
	 */
	function withResources( string resourcesPath ) {
		//if it has a resourcefolder it uses that one
		//if its empty then use src\main\resources
		setResourcePath( fileSystemutil.resolvePath( resourcesPath, getProjectRoot() ) )
		return this;
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
	 * Enables JAR creation and merges the supplied dependency JARs.
	 *
	 * @jarName The output fat JAR filename.
	 * @includeJars Dependency JAR paths or directories to merge.
	 * @options Fat JAR configuration options.
	 * @returns The current DSL instance.
	 */
	function toFatJar( string jarName='', any includeJars=[], struct options={} ) {
		if( isSimpleValue( arguments.includeJars ) ) {
			arguments.includeJars = listToArray( arguments.includeJars, ",", true );
		}
		arguments.includeJars = arguments.includeJars.map( function( jarPath ) {
			return fileSystemutil.resolvePath( arguments.jarPath, getProjectRoot() );
		} );
		setFatJarPaths( arguments.includeJars );
		if( arguments.jarName.len() ) {
			setFatJarNameString( arguments.jarName );
		}
		if( arguments.options.len() ) {
			configureFatJar( arguments.options );
		}
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

			if ( len( getFatJarPaths() ) ) {
				job.start( 'Build Fat JAR' );
				buildFatJar();
				job.complete();
 			}

			job.addLog( 'Adding JAR resources when available.' );
			moveResources();
		}

		job.complete( getVerbose() );

		return {
			"projectRoot"           : getProjectRoot(),
			"jdkBinDirectory"       : getJavaBinFolder(),
			"sourcePaths"           : getSourcePaths(),
			"classOutputDirectory"  : fileSystemutil.resolvePath( getClassOutputDirectory(), getProjectRoot() ),
			"libsDirectory"         : fileSystemutil.resolvePath( getLibsDir(), getProjectRoot() ),
			"jarPath"               : getGeneratedJarPath(),
			"javaDocsPath"          : getUseJavaDoc()
				? fileSystemutil.resolvePath( getJavaDocDestinationDir(), getProjectRoot() )
				: "",
			"resourcePath"          : fileSystemutil.resolvePath( getResourcePath(), getProjectRoot() ),
			"classPaths"            : getClassPaths(),
			"fatJarPaths"           : getFatJarPaths(),
			"compileOptions"        : getCompileOptionsString(),
			"jarOptions"            : getJarOptionsString(),
			"encoding"              : getEncode(),
			"manifest"              : getCustomManifestParams()
		};
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
	function writeTempClassFiles( string tempSrcFileName, array sourcePath = getSourcePaths(), string extension=".class" ) {

		var classOutput = fileSystemutil.normalizeSlashes(
			fileSystemutil.resolvePath( getClassOutputDirectory(), getProjectRoot() )
		);

		var globber = wirebox.getInstance( 'globber' );

		currentSourceList = globber
			.setPattern( sourcePath )
			.asQuery()
			.matches()
			.filter(( row ) => row.type=="file" && row.name.endsWith( extension ))
			.reduce(( acc, row ) => {
				var relativeDirectory = replaceNoCase(
					fileSystemutil.normalizeSlashes( row.directory ),
					classOutput,
					""
				);
				relativeDirectory = reReplace( relativeDirectory, "^/+", "" );
				var relativePath = relativeDirectory.len() ? relativeDirectory & "/" & row.name : row.name;
				return listappend( acc, "-C #classOutput# #relativePath#", chr(10) );
			}, "")

		/* job.addLog( "currentSourceList -> " & serialize( currentSourceList ) );
		job.addLog( "currentSourceList -> " & currentSourceList.len() ); */

		/* job.addLog( "finalSourceList -> " & finalSourceList ); */

		fileWrite( tempSrcFileName, currentSourceList );
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
	 * Adds configured resources to the generated JAR.
	 *
	 * @returns Nothing. Resources are added to the generated JAR when configured.
	 */
	function moveResources() {
		var currentResourcePath = fileSystemutil.resolvePath( getResourcePath(), getProjectRoot() );
		//job.addLog( "moveRes resPath: #currentResourcePath#" );

		if( directoryExists( currentResourcePath ) ) {
			job.addLog( "Including resources from: #replaceNoCase( currentResourcePath, getProjectRoot(), "" )#" );
			// have to replicate this command
			// run ""jar" uf "D:\Javatest\new-tests\libs\new-tests.jar" -C "D:\Javatest\gradle-test-resource\src\main\resources\" ."
			var jarName = getJarNameString();
			//job.addLog( "moveRes jarname: #jarName#" );
			var currentLibsDir = fileSystemutil.resolvePath( getLibsDir(), getProjectRoot() );
			//job.addLog( "moveRes currLibsDir: #currentLibsDir#" );

			j = nativeRunCommand( getJavaBinFolder() & "jar", 'uf "#currentLibsDir##jarName#" -C #currentResourcePath# .' );

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
	 * @returns Nothing. Dependency contents are merged according to the configured options.
	 */
	function buildFatJar() {
		var options = getFatJarOptions();
		var mergedDependencyEntries = {};
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
		if( outputJar != thinJarPath && !fileExists( outputJar ) ) {
			fileCopy( thinJarPath, outputJar, true );
		}
		setGeneratedJarPath( outputJar );

		for( var dependencyJar in getFatJarPaths() ) {
			if( !fileExists( dependencyJar ) ) {
				throw(
					message="Fat JAR dependency does not exist: #dependencyJar#",
					type="commandException"
				);
			}

			var extractDirectory = tempDir & 'fatJar#createUUID()#';
			if( !directoryExists( extractDirectory ) ) {
				directoryCreate( extractDirectory, true );
			}
			if( !directoryExists( extractDirectory ) ) {
				throw(
					message="Unable to create fat JAR extraction directory: #extractDirectory#",
					type="commandException"
				);
			}

			try {
				zip action="unzip" file="#dependencyJar#" destination="#extractDirectory#" overwrite="true";

				removeDependencyManifest( extractDirectory );
				if( options.excludeSignatures ) {
					removeDependencySignatures( extractDirectory );
				}
				if( options.mergeServiceDescriptors ) {
					mergeServiceDescriptors( outputJar, extractDirectory );
				}
				applyDuplicatePolicy( extractDirectory, mergedDependencyEntries, options.duplicatePolicy );

				var mergeCommand = nativeRunCommand( getJavaBinFolder() & "jar", 'uf "#outputJar#" -C "#extractDirectory#" .' );
				if( getVerbose() ) {
					job.addLog( mergeCommand );
				}
				runCompileCommand( mergeCommand, "Fat JAR dependency merge" );
			} finally {
				if( directoryExists( extractDirectory ) ) {
					directoryDelete( extractDirectory, true );
				}
			}
		}
	}

	/**
	 * Removes a dependency manifest before merging its contents.
	 *
	 * @extractDirectory The extracted dependency directory.
	 * @returns Nothing.
	 */
	private function removeDependencyManifest( required string extractDirectory ) {
		var metaInfDirectory = arguments.extractDirectory & "/META-INF";
		if( !directoryExists( metaInfDirectory ) ) {
			return;
		}

		var manifestFile = metaInfDirectory & "/MANIFEST.MF";
		if( fileExists( manifestFile ) ) {
			fileDelete( manifestFile );
		}
	}

	/**
	 * Removes dependency signature files before merging archive contents.
	 *
	 * @extractDirectory The extracted dependency directory.
	 * @returns Nothing.
	 */
	private function removeDependencySignatures( required string extractDirectory ) {
		var metaInfDirectory = arguments.extractDirectory & "/META-INF";
		if( !directoryExists( metaInfDirectory ) ) {
			return;
		}

		for( var filePath in directoryList( metaInfDirectory, true, "array" ) ) {
			if(
				fileExists( filePath )
				&& reFindNoCase( "(^|[\\/])META-INF[\\/].*\.(SF|RSA|DSA)$", filePath )
			) {
				fileDelete( filePath );
			}
		}
	}

	/**
	 * Applies the configured duplicate-entry policy to extracted dependency files.
	 *
	 * @extractDirectory The extracted dependency directory.
	 * @mergedDependencyEntries The entries already merged from dependencies.
	 * @duplicatePolicy The duplicate policy: first, last, or error.
	 * @returns Nothing.
	 */
	private function applyDuplicatePolicy(
		required string extractDirectory,
		required struct mergedDependencyEntries,
		required string duplicatePolicy
	) {
		for( var filePath in directoryList( arguments.extractDirectory, true, "array" ) ) {
			if( !fileExists( filePath ) ) {
				continue;
			}

			var entryName = replaceNoCase(
				fileSystemutil.normalizeSlashes( filePath ),
				fileSystemutil.normalizeSlashes( arguments.extractDirectory ),
				""
			);
			entryName = reReplace( entryName, "^/+", "" );

			if( !arguments.mergedDependencyEntries.keyExists( entryName ) ) {
				arguments.mergedDependencyEntries[ entryName ] = true;
				continue;
			}

			switch( arguments.duplicatePolicy ) {
				case "first":
					fileDelete( filePath );
					break;
				case "error":
					throw(
						message="Duplicate fat JAR entry: #entryName#",
						type="commandException"
					);
			}
		}
	}

	/**
	 * Combines service provider descriptors from a dependency into the output JAR.
	 *
	 * @outputJar The output JAR path.
	 * @extractDirectory The extracted dependency directory.
	 * @returns Nothing.
	 */
	private function mergeServiceDescriptors( required string outputJar, required string extractDirectory ) {
		var servicesDirectory = arguments.extractDirectory & "/META-INF/services";
		if( !directoryExists( servicesDirectory ) ) {
			return;
		}

		var outputDirectory = tempDir & "fatJarOutput#createUUID()#";
		directoryCreate( outputDirectory, true );

		try {
			zip action="unzip" file="#arguments.outputJar#" destination="#outputDirectory#" overwrite="true";

			for( var serviceFile in directoryList( servicesDirectory, true, "array" ) ) {
				if( !fileExists( serviceFile ) ) {
					continue;
				}

				var relativePath = replaceNoCase(
					fileSystemutil.normalizeSlashes( serviceFile ),
					fileSystemutil.normalizeSlashes( servicesDirectory ),
					""
				);
				relativePath = reReplace( relativePath, "^/+", "" );
				var outputServiceFile = outputDirectory & "/META-INF/services/" & relativePath;
				var outputServiceDirectory = getDirectoryFromPath( outputServiceFile );
				if( !directoryExists( outputServiceDirectory ) ) {
					directoryCreate( outputServiceDirectory, true );
				}

				var providers = [];
				if( fileExists( outputServiceFile ) ) {
					providers.append( fileRead( outputServiceFile ).listToArray( chr(10), true ), true );
				}
				providers.append( fileRead( serviceFile ).listToArray( chr(10), true ), true );
				fileWrite( outputServiceFile, providers.map( ( provider ) => trim( provider ) ).filter( ( provider ) => provider.len() ).toList( chr(10) ) );
			}

			var mergedJarZip = arguments.outputJar & ".zip";
			if( fileExists( mergedJarZip ) ) {
				fileDelete( mergedJarZip );
			}
			zip action="zip" file="#arguments.outputJar#" source="#outputDirectory#" overwrite="true";
			if( fileExists( arguments.outputJar ) ) {
				fileDelete( arguments.outputJar );
			}
			fileMove( mergedJarZip, arguments.outputJar );
			directoryDelete( servicesDirectory, true );
		} finally {
			if( directoryExists( outputDirectory ) ) {
				directoryDelete( outputDirectory, true );
			}
		}
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
