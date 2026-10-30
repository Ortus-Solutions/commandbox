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
		model[ "sourceRoots" ] = roots( config.source ?: "src/main/java", root, true );
		model[ "outputDirectory" ] = path( config.classes ?: "build/classes/java/main", root );
		model[ "libsDirectory" ] = path( config.libsDir ?: "build/libs", root );
		model[ "resourceRoots" ] = roots( config.resources ?: "src/main/resources", root, false );
		model[ "release" ] = "";
		if( structKeyExists( config.compileOptions ?: {}, "release" ) ) {
			var release = config.compileOptions.release & "";
			if( !reFind( "^[1-9][0-9]*$", release ) ) {
				throw( type="commandException", message="java.compileOptions.release must be a positive Java release." );
			}
			model.release = release;
		}
		model[ "classPath" ] = [];
		model[ "dependencies" ] = [];
		for( var entry in paths( config.classPath ?: [] ) ) {
			var absolute = path( entry, root );
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
				throw(
					type="commandException",
					message="Java classPath #kind# is missing or contains no JARs: #absolute#",
					detail="Run `install` to install the dependencies, or correct java.classPath in box.json."
				);
			}
			resolved = resolved.map( function( item ) { return cleanPath( item ); } ).sort( "text" );
			var item = structNew( "ordered" );
			item[ "kind" ] = kind;
			item[ "path" ] = absolute;
			item[ "resolved" ] = resolved;
			model.classPath.append( item );
			for( var dependency in resolved ) {
				if( !model.dependencies.find( dependency ) ) model.dependencies.append( dependency );
			}
		}
		model.dependencies.sort( "text" );
		model[ "manifest" ] = ordered( config.manifest ?: {} );
		return model;
	}

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

	private string function path( required string value, required string root ) {
		return cleanPath( fileSystemUtil.resolvePath( arguments.value, arguments.root ) );
	}

	private string function cleanPath( required string value ) {
		return reReplace( fileSystemUtil.normalizeSlashes( arguments.value ), "/+$", "" );
	}

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
