/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I write IntelliJ module metadata. The .iml format takes explicit library entries,
* so my JAR entries are a snapshot that must be regenerated after a dependency change.
*
*/
component extends="BaseEmitter" {

	boolean function detect( required string root ) {
		return directoryExists( arguments.root & "/.idea" )
			|| directoryList( arguments.root, false, "path", "*.iml" ).len() > 0;
	}

	array function files( required struct model ) {
		var moduleFile = "commandbox-java.iml";
		var manager = "/module/component[@name='NewModuleRootManager']";
		var content = manager & "/content[@url='file://$MODULE_DIR$']";
		var patches = [];
		patches.append( patch( manager & "/@inherit-compiler-output", [ "false" ], manager ) );
		patches.append( patch(
			manager & "/output", [ '<output url="#escape( url( arguments.model.outputDirectory, arguments.model ) )#"/>' ],
			manager
		) );
		patches.append( patch( manager & "/orderEntry[@type='inheritedJdk']", [ '<orderEntry type="inheritedJdk"/>' ], manager ) );
		patches.append( patch(
			manager & "/orderEntry[@type='sourceFolder']", [ '<orderEntry type="sourceFolder" forTests="false"/>' ], manager
		) );
		for( var root in arguments.model.sourceRoots ) {
			var rootURL = url( root, arguments.model );
			patches.append( patch(
				content & "/sourceFolder[@url=#literal( rootURL )#]",
				[ '<sourceFolder url="#escape( rootURL )#" isTestSource="false"/>' ], content
			) );
		}
		for( var root in arguments.model.resourceRoots ) {
			if( !directoryExists( root ) || arguments.model.sourceRoots.find( root ) ) continue;
			var rootURL = url( root, arguments.model );
			patches.append( patch(
				content & "/sourceFolder[@url=#literal( rootURL )#]",
				[ '<sourceFolder url="#escape( rootURL )#" type="java-resource"/>' ], content
			) );
		}
		// Built with chr( 36 ) so the $MODULE_DIR$ placeholder is not read as syntax.
		var placeholder = chr( 36 ) & "MODULE_DIR" & chr( 36 );
		for( var classPathEntry in arguments.model.classPath ) {
			var base = relative( classPathEntry.path, arguments.model );
			var libraries = [];
			for( var jar in classPathEntry.resolved ) {
				libraries.append(
					'<orderEntry type="module-library"><library><CLASSES><root url="#escape( jarURL( jar, arguments.model ) )#"/></CLASSES><JAVADOC/><SOURCES/></library></orderEntry>'
				);
			}
			// Replacing everything under a declared classPath entry is what removes
			// libraries left behind by a dependency upgrade.
			patches.append( patch(
				classPathEntry.kind == "directory"
					? manager & "/orderEntry[@type='module-library' and starts-with(library/CLASSES/root/@url,#literal( "jar" & chr( 58 ) & "//" & placeholder & "/" & base & "/" )#)]"
					: manager & "/orderEntry[@type='module-library' and library/CLASSES/root/@url=#literal( jarURL( base, arguments.model ) )#]",
				libraries,
				manager
			) );
		}
		var result = [ {
			"path" : moduleFile, "format" : "xml", "seed" : '<module type="JAVA_MODULE" version="4"/>',
			"containers" : [
				container( manager, "/module", '<component name="NewModuleRootManager" inherit-compiler-output="false"/>' ),
				container( content, manager, '<content url="file://$MODULE_DIR$"/>' )
			],
			"patches" : patches
		} ];
		var modules = "/project/component[@name='ProjectModuleManager']/modules";
		result.append( {
			"path" : ".idea/modules.xml", "format" : "xml", "seed" : '<project version="4"/>',
			"containers" : [
				container(
					"/project/component[@name='ProjectModuleManager']", "/project", '<component name="ProjectModuleManager"/>'
				),
				container( modules, "/project/component[@name='ProjectModuleManager']", "<modules/>" )
			],
			"patches" : [ patch(
				modules & "/module[@filepath='$PROJECT_DIR$/#moduleFile#']",
				[ '<module fileurl="file://$PROJECT_DIR$/#moduleFile#" filepath="$PROJECT_DIR$/#moduleFile#"/>' ], modules
			) ]
		} );
		if( len( arguments.model.release ) ) {
			result.append( {
				"path" : ".idea/compiler.xml", "format" : "xml", "seed" : '<project version="4"/>',
				"containers" : [
					container( "/project/component[@name='CompilerConfiguration']", "/project", '<component name="CompilerConfiguration"/>' ),
					container(
						"/project/component[@name='CompilerConfiguration']/bytecodeTargetLevel",
						"/project/component[@name='CompilerConfiguration']", "<bytecodeTargetLevel/>"
					)
				],
				"patches" : [ patch(
					"/project/component[@name='CompilerConfiguration']/bytecodeTargetLevel/module[@name='commandbox-java']",
					[ '<module name="commandbox-java" target="#escape( arguments.model.release )#"/>' ],
					"/project/component[@name='CompilerConfiguration']/bytecodeTargetLevel"
				) ]
			} );
			result[ 1 ].patches.append( patch(
				manager & "/@LANGUAGE_LEVEL",
				[ "JDK_" & ( val( arguments.model.release ) <= 8 ? "1_" : "" ) & arguments.model.release ],
				manager
			) );
		}
		return result;
	}

	private string function url( required string path, required struct model ) {
		var value = relative( arguments.path, arguments.model );
		if( value == "." ) return "file://$MODULE_DIR$";
		return value == arguments.path ? "file://" & value : "file://$MODULE_DIR$/" & value;
	}

	private string function jarURL( required string path, required struct model ) {
		return replace( url( arguments.path, arguments.model ), "file://", "jar://" ) & "!/";
	}
}
