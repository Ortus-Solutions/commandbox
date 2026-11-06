/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I build the editor-neutral model of a project's box.json java block. Everything
* editor-specific lives in an emitter, never here.
*
*/
component singleton {

	property name="packageService" inject="PackageService";
	property name="fileSystemUtil" inject="FileSystem";
	property name="wirebox"        inject="wirebox";

	/**
	 * Builds the editor-neutral model of a project's box.json java block.
	 *
	 * @projectRoot The directory containing the project's box.json.
	 * @returns The model every emitter reads from.
	 */
	struct function build( required string projectRoot ) {
		var root = fileSystemUtil.resolvePath( arguments.projectRoot );
		var descriptor = packageService.readPackageDescriptorRaw( root );
		if( !isStruct( descriptor.java ?: "" ) ) {
			throw( type="commandException", message="No java block in #root#/box.json. Run `java init` first." );
		}
		var config = descriptor.java;
		var model = structNew( "ordered" );
		model[ "schemaVersion" ] = 1;
		model[ "projectRoot" ] = cleanPath( root );
		model[ "name" ] = descriptor.slug ?: listLast( model.projectRoot, "/" );
		model[ "sourceRoots" ] = roots( config.sourcePath ?: "src/main/java", root, true );
		model[ "testSourceRoots" ] = roots( config.testSourcePath ?: "src/test/java", root, true );
		// The editor's compiler is its own incremental compiler and owns its output
		// folder, so it never shares classesDirectory with our javac run: JDT requires
		// an empty output folder when it takes it over. Sources and the dependency
		// globs stay shared, since both are read-only inputs.
		model[ "outputDirectory" ] = path( "build/ide/classes", root );
		model[ "testOutputDirectory" ] = path( config.testClassesDirectory ?: "build/classes/java/test", root );
		model[ "libsDirectory" ] = path( config.libsDirectory ?: "build/libs", root );
		model[ "resourceRoots" ] = roots( config.resourcesDirectory ?: "src/main/resources", root, false );
		model[ "testResourceRoots" ] = roots( config.testResourcesDirectory ?: "src/test/resources", root, false );
		model[ "release" ] = "";
		if( structKeyExists( config.compileOptions ?: {}, "release" ) ) {
			var release = config.compileOptions.release & "";
			if( !reFind( "^[1-9][0-9]*$", release ) ) {
				throw( type="commandException", message="java.compileOptions.release must be a positive Java release." );
			}
			model.release = release;
		}
		// The runtime and test classpath fall back to the same convention directories
		// the compile DSL uses, so a freshly `java init`-ed project (which writes empty
		// arrays) still points the editor at its installed dependencies.
		model[ "classPath" ] = classPathEntries( classPathConfig( config.classPath ?: [], "dist/dependencies" ), root, hasValue( config.classPath ?: [] ) );
		model[ "testClassPath" ] = classPathEntries( classPathConfig( config.testClassPath ?: [], "dist/test-dependencies" ), root, false );
		model[ "dependencies" ] = [];
		for( var entry in model.classPath ) {
			for( var dependency in entry.resolved ) {
				if( !model.dependencies.find( dependency ) ) model.dependencies.append( dependency );
			}
		}
		for( var entry in model.testClassPath ) {
			for( var dependency in entry.resolved ) {
				if( !model.dependencies.find( dependency ) ) model.dependencies.append( dependency );
			}
		}
		model.dependencies.sort( "text" );
		model[ "manifest" ] = ordered( config.manifest ?: {} );
		return model;
	}

	/**
	 * True when a configured value actually holds something.
	 *
	 * @value The configured value.
	 */
	private boolean function hasValue( required any value ) {
		if( isSimpleValue( arguments.value ) ) {
			return len( trim( arguments.value ) ) > 0;
		}
		if( isArray( arguments.value ) ) {
			return arguments.value.len() > 0;
		}
		return false;
	}

	/**
	 * Returns the configured classpath value, or the convention directory when the
	 * project left it empty — the same fallback the compile DSL applies.
	 *
	 * @value The configured classpath value: a string, list, array, or empty.
	 * @defaultDirectory The convention directory to use when nothing is configured.
	 */
	private any function classPathConfig( required any value, required string defaultDirectory ) {
		if( isSimpleValue( arguments.value ) && !len( trim( arguments.value ) ) ) {
			return [ arguments.defaultDirectory ];
		}
		if( isArray( arguments.value ) && !arguments.value.len() ) {
			return [ arguments.defaultDirectory ];
		}
		return arguments.value;
	}

	/**
	 * Resolves a configured classpath value into editor-ready entries.
	 *
	 * @value The configured classpath value: a string, list, or array.
	 * @root The project root used to resolve relative paths.
	 * @strict When true, an entry that is missing or matches no JARs is an error.
	 */
	private array function classPathEntries( required any value, required string root, required boolean strict ) {
		var result = [];
		for( var entry in paths( arguments.value ) ) {
			var absolute = path( entry, arguments.root );
			var kind = reFind( "[*?]", entry ) ? "glob" : ( reFindNoCase( "\.jar$", entry ) ? "jar" : "directory" );
			var resolved = [];
			if( kind == "glob" ) {
				resolved = wirebox.getInstance( "Globber" ).setPattern( absolute ).matches().filter( function( item ) {
					return fileExists( item ) && reFindNoCase( "\.jar$", item );
				} );
			} else if( kind == "jar" ) {
				if( fileExists( absolute ) ) resolved.append( absolute );
			} else if( directoryExists( absolute ) ) {
				resolved = directoryList( absolute, true, "path", "*.jar" );
			}
			if( !resolved.len() ) {
				if( arguments.strict ) {
					throw(
						type="commandException",
						message="Java classPath #kind# is missing or contains no JARs: #absolute#",
						detail="Run `install` to install the dependencies, or correct java.classPath in box.json."
					);
				}
				// Keep the entry even with nothing in it: glob-based editors (VS Code)
				// need the directory so a later `install` is picked up without
				// regenerating metadata. Jar-listing editors just emit nothing for it.
			}
			resolved = resolved.map( function( item ) { return cleanPath( item ); } ).sort( "text" );
			var item = structNew( "ordered" );
			item[ "kind" ] = kind;
			item[ "path" ] = absolute;
			item[ "resolved" ] = resolved;
			result.append( item );
		}
		return result;
	}

	/**
	 * Normalizes a configured path value into a de-duplicated array of strings.
	 *
	 * @value A string, comma-delimited string, or array of paths.
	 * @returns The individual path entries.
	 */
	array function paths( required any value ) {
		if( !isArray( arguments.value ) && !isSimpleValue( arguments.value ) ) {
			throw( type="commandException", message="Java paths must be strings or arrays of strings." );
		}
		var result = [];
		var entries = isArray( arguments.value ) ? arguments.value : listToArray( arguments.value );
		for( var entry in entries ) {
			if( !isSimpleValue( entry ) || !len( trim( entry ) ) ) {
				throw( type="commandException", message="Java paths must contain non-empty strings." );
			}
			if( !result.find( trim( entry ) ) ) result.append( trim( entry ) );
		}
		return result;
	}

	/**
	 * Resolves configured source or resource roots into absolute editor roots.
	 *
	 * A glob or a single file resolves to the directory that contains it, because an
	 * editor wants the root it should index, not the individual matches.
	 *
	 * @value The configured value: a string, list, or array of paths.
	 * @root The project root used to resolve relative paths.
	 * @sources True for source roots, which may be globs or files.
	 * @returns The de-duplicated absolute roots.
	 */
	private array function roots( required any value, required string root, required boolean sources ) {
		var result = [];
		for( var entry in paths( arguments.value ) ) {
			var resolved = path( entry, arguments.root );
			// A source glob's fixed directory is its editor source root, not each matching file.
			if( arguments.sources && reFind( "[*?]", resolved ) ) {
				resolved = getDirectoryFromPath( left( resolved, reFind( "[*?]", resolved ) - 1 ) );
			} else if( arguments.sources && reFindNoCase( "\.java$", resolved ) ) {
				resolved = getDirectoryFromPath( resolved );
			}
			resolved = cleanPath( resolved );
			if( !result.find( resolved ) ) result.append( resolved );
		}
		return result;
	}

	/**
	 * Resolves one configured path against the project root.
	 *
	 * @value The configured path.
	 * @root The project root.
	 * @returns The cleaned absolute path.
	 */
	private string function path( required string value, required string root ) {
		return cleanPath( fileSystemUtil.resolvePath( arguments.value, arguments.root ) );
	}

	/**
	 * Normalizes slashes and strips the trailing separator from a path.
	 *
	 * @value The path to clean.
	 * @returns The cleaned path.
	 */
	private string function cleanPath( required string value ) {
		return reReplace( fileSystemUtil.normalizeSlashes( arguments.value ), "/+$", "" );
	}

	/**
	 * Copies a value into an ordered struct, sorting keys so a repeated run produces
	 * the same output.
	 *
	 * @value The value to order.
	 * @returns The ordered copy.
	 */
	private any function ordered( required any value ) {
		if( isStruct( arguments.value ) ) {
			var result = structNew( "ordered" );
			for( var key in structKeyArray( arguments.value ).sort( "text" ) ) {
				result[ key ] = ordered( arguments.value[ key ] );
			}
			return result;
		}
		if( isArray( arguments.value ) ) {
			return arguments.value.map( function( item ) { return ordered( item ); } );
		}
		return arguments.value;
	}
}
