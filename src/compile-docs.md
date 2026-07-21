# Compile DSL

The Compile DSL compiles Java source and optionally creates JAR files, Javadocs,
and fat JARs from CommandBox commands and task runners.


## Defaults

`compile()` sets the project root from `resolvePath( "" )`. In a task runner,
this resolves from the directory containing `Task.cfc`.

| Setting | Default |
| --- | --- |
| Java sources | `src/main/java` |
| Compiled classes | `classes/java/main` |
| JAR directory | `libs` |
| Resources | `src/main/resources` |
| Javadocs | `javaDocs/main` |


## Basic Compilation

Java source is expected in `src/main/java` by default. Compiled classes are
written to `classes/java/main`.

```js
compile().run();
```

## Create a JAR

Call `.toJar()` to create a JAR in `libs`.

```js
var result = compile()
	.toJar()
	.run();
```

Provide a name for a specific filename:

```js
var result = compile()
	.toJar( "example.jar" )
	.run();
```

The returned `result.jarPath` contains the generated JAR path.

## Configure Source, Classes, and JAR Locations

```js
var result = compile()
	.fromSource( "src/custom/java" )
	.toClasses( "build/classes" )
	.libsDir( "build/libs" )
	.toJar( "example.jar" )
	.run();
```

`.fromSource()` accepts a directory, source-file glob, comma-delimited string,
or array of source paths.

```js
compile()
	.fromSource( [ "src/main/java", "src/generated/java" ] )
	.toJar( "example.jar" )
	.run();
```

## Resources

Resources are taken from `src/main/resources` by default and copied into the
JAR with their directory structure preserved.

```js
compile()
	.toJar( "example.jar" )
	.run();
```

Use `.withResources()` for another resource directory:

```js
compile()
	.withResources( "src/resources" )
	.toJar( "example.jar" )
	.run();
```

## Manifest Entries

Use `.manifest()` to add or override manifest attributes.

```js
compile()
	.manifest( {
		"Implementation-Title"   : "Example Application",
		"Implementation-Version" : "1.2.3",
		"Main-Class"             : "example.App"
	} )
	.toJar( "example.jar" )
	.run();
```

## Compiler Options

`.compileOptions()` accepts a typed struct. See the [Oracle `javac` documentation](https://docs.oracle.com/en/java/javase/21/docs/specs/man/javac.html)
for the underlying compiler behavior.

```js
compile()
	.compileOptions( {
		// Target a Java SE release and class-file version.
		"release" : 8,
		// Set the source language level.
		"source" : 8,
		// Set the generated class-file target.
		"target" : 8,
		// Decode Java source files using UTF-8.
		"encoding" : "UTF-8",
		// Include selected debugging metadata.
		"debug" : [ "lines", "source" ],
		// Show deprecation warnings.
		"deprecation" : true,
		// Enable preview language features.
		"enablePreview" : false,
		// Suppress compiler warnings.
		"nowarn" : false,
		// Store method-parameter names for reflection.
		"parameters" : true,
		// Treat warnings as compilation errors.
		"werror" : false,
		// Enable selected lint warnings.
		"lint" : [ "deprecation", "unchecked" ],
		// Limit the number of reported errors.
		"maxErrors" : 50,
		// Limit the number of reported warnings.
		"maxWarnings" : 50,
		// Select annotation-processing mode.
		"proc" : "full",
		// Control implicit class generation.
		"implicit" : "class",
		// Select annotation processors.
		"processors" : [ "com.example.Processor" ],
		// Locate annotation processors.
		"processorPath" : [ "libs/processors" ],
		// Locate additional source files.
		"sourcePath" : [ "src/generated" ],
		// Locate compiled modules.
		"modulePath" : [ "libs/modules" ],
		// Locate module source trees.
		"moduleSourcePath" : [ "src/modules" ],
		// Add root modules to resolve.
		"addModules" : [ "java.sql", "java.naming" ],
		// Restrict observable modules.
		"limitModules" : [ "java.base", "java.sql" ]
	} )
	.toJar( "example.jar" )
	.run();
```

The top-level `.setVerbose( true )` controls verbose compiler output. Verbosity
is not configured inside the compiler options struct.

## JAR Options

`.jarOptions()` accepts a typed struct. See the [Oracle `jar` documentation](https://docs.oracle.com/en/java/javase/21/docs/specs/man/jar.html)
for the underlying archive behavior.

```js
compile()
	.jarOptions( {
		// Store entries without ZIP compression.
		"compress" : false,
		// Set the executable JAR entry point.
		"mainClass" : "example.App",
		// Set archive entry timestamps; accepts now() or a date string.
		"date" : now(),
		// Set the module version for a modular JAR.
		"moduleVersion" : "1.0.0",
		// Compute hashes for matching modules.
		"hashModules" : "com.example.*",
		// Locate modules used for hash generation.
		"modulePath" : [ "libs/modules" ],
		// Suppress the generated manifest.
		"noManifest" : false
	} )
	.toJar( "example.jar" )
	.run();
```

The `date` option accepts either a CFML date value, such as `now()`, or a date
string. CFML date values are formatted for the JAR tool; date strings are passed
through in the format supplied. If no date is provided, the JAR tool uses its
normal timestamp behavior.

## Javadocs

Call `.withJavaDocs()` to generate documentation in `javaDocs/main`.

```js
var result = compile()
	.withJavaDocs()
	.run();
```

The returned `result.javaDocsPath` contains the generated documentation path.

## Classpaths

`.withClassPath()` accepts a JAR, a directory containing JARs, a comma-delimited
string, or an array. Directories are expanded into their JAR files.

```js
var result = compile()
	.withClassPath( "libs" )
	.toJar( "example.jar" )
	.run();
```

## Fat JARs

`.toFatJar()` creates the project JAR and merges supplied dependency JARs into
it.

```js
var result = compile()
	.withClassPath( "libs/dependencies" )
	.toFatJar( "example-all.jar", [ "libs/dependencies" ] )
	.run();
```

Configure merge behavior with `configureFatJar()`:

```js
compile()
	.configureFatJar( {
		// Combine META-INF/services provider files.
		"mergeServiceDescriptors" : true,
		// Remove dependency signature files from the merged archive.
		"excludeSignatures" : true,
		// Choose which duplicate regular entry wins.
		"duplicatePolicy" : "last"
	} )
	.toFatJar( "example-all.jar", [ "libs/dependency-one.jar", "libs/dependency-two.jar" ] )
	.run();
```

`duplicatePolicy` accepts `last`, `first`, or `error`. Dependencies are applied
in the order supplied. Service providers are combined line by line when
`mergeServiceDescriptors` is enabled. Dependency signature files are excluded
when `excludeSignatures` is enabled.

## Result Metadata

`run()` returns a struct containing metadata about the operation. Every key is
present; values for operations not requested are empty strings, arrays, or
structs.

```js
var result = compile()
	.toJar( "example.jar" )
	.run();

print.line( result.jarPath );
print.line( result.classOutputDirectory );
```

The result includes `projectRoot`, `jdkBinDirectory`, `sourcePaths`,
`classOutputDirectory`, `libsDirectory`, `jarPath`, `javaDocsPath`,
`resourcePath`, `classPaths`, `fatJarPaths`, `compileOptions`, `jarOptions`,
`encoding`, and `manifest`.# Compile DSL
