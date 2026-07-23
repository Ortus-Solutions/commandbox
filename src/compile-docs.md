# Compile DSL

The DSL is also available through the `java compile` command. The command
returns the same result metadata as the DSL and prints a short operation
summary. Use `--JSON` to print and return the result struct without the
summary.

```bash
java compile --jar jarName=example.jar source=src/main/java
java compile compileOptions:release=8 compileOptions:debug=lines,source
java compile jarOptions:mainClass=example.App manifest:Main-Class=example.App
java compile --JSON
```

Repeated `manifest:`, `compileOptions:`, `jarOptions:`, and `fatJarOptions:`
arguments are collected into structs. Comma-delimited values are converted to
arrays for options that accept lists.

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

Equivalent command:

```bash
java compile
```

## Create a JAR

Call `.toJar()` to create a JAR in `libs`.

```js
var result = compile()
	.toJar()
	.run();
```

Equivalent command:

```bash
java compile --jar
```

Provide a name for a specific filename:

```js
var result = compile()
	.toJar( "example.jar" )
	.run();
```

Equivalent command:

```bash
java compile --jar jarName=example.jar
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

Equivalent command:

```bash
java compile source=src/custom/java classes=build/classes libsDir=build/libs --jar jarName=example.jar
```

`.fromSource()` accepts a directory, source-file glob, comma-delimited string,
or array of source paths.

```js
compile()
	.fromSource( [ "src/main/java", "src/generated/java" ] )
	.toJar( "example.jar" )
	.run();
```

Equivalent command:

```bash
java compile source=src/main/java,src/generated/java --jar jarName=example.jar
```

## Resources

Resources are taken from `src/main/resources` by default and copied into the
JAR with their directory structure preserved.

```js
compile()
	.toJar( "example.jar" )
	.run();
```

Equivalent command:

```bash
java compile --jar jarName=example.jar
```

Use `.withResources()` for another resource directory:

```js
compile()
	.withResources( "src/resources" )
	.toJar( "example.jar" )
	.run();
```

Equivalent command:

```bash
java compile resources=src/resources --jar jarName=example.jar
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

Equivalent command:

```bash
java compile --jar jarName=example.jar manifest:Implementation-Title="Example Application" manifest:Implementation-Version=1.2.3 manifest:Main-Class=example.App
```

When the compile project contains a `box.json`, package metadata is also used
to populate the JAR manifest automatically. The DSL maps package fields such as
`name`, `slug`, `version`, `author`, `shortDescription`, `homepage`,
`documentation`, and the first license URL to manifest attributes. An optional
`box.json` `manifest` struct is applied last, so those values override the
generated package metadata.

For example:

```json
{
	"name" : "Example",
	"slug" : "example",
	"version" : "1.0.0",
	"manifest" : {
		"Main-Class" : "example.App",
		"Implementation-Version" : "1.0.0"
	}
}
```

The explicit `.manifest()` call takes precedence over values loaded from
`box.json`.

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

Equivalent command:

```bash
java compile --jar jarName=example.jar compileOptions:release=8 compileOptions:source=8 compileOptions:target=8 compileOptions:encoding=UTF-8 compileOptions:debug=lines,source compileOptions:deprecation=true compileOptions:parameters=true compileOptions:lint=deprecation,unchecked compileOptions:maxErrors=50 compileOptions:maxWarnings=50 compileOptions:proc=full compileOptions:implicit=class compileOptions:processors=com.example.Processor compileOptions:processorPath=libs/processors compileOptions:sourcePath=src/generated compileOptions:modulePath=libs/modules compileOptions:moduleSourcePath=src/modules compileOptions:addModules=java.sql,java.naming compileOptions:limitModules=java.base,java.sql
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

Equivalent command:

```bash
java compile --jar jarName=example.jar jarOptions:compress=false jarOptions:mainClass=example.App jarOptions:date=2026-01-01T00:00:00Z jarOptions:moduleVersion=1.0.0 jarOptions:hashModules=com.example.* jarOptions:modulePath=libs/modules jarOptions:noManifest=false
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

Equivalent command:

```bash
java compile --javaDocs --JSON
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

Equivalent command:

```bash
java compile classPath=libs --jar jarName=example.jar
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

Equivalent command:

```bash
java compile classPath=libs/dependencies --fatJar fatJarName=example-all.jar fatJarJars=libs/dependencies
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

Equivalent command:

```bash
java compile --fatJar fatJarName=example-all.jar fatJarJars=libs/dependency-one.jar,libs/dependency-two.jar fatJarOptions:mergeServiceDescriptors=true fatJarOptions:excludeSignatures=true fatJarOptions:duplicatePolicy=last
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

Equivalent command:

```bash
java compile --jar jarName=example.jar --JSON
```

The result includes `projectRoot`, `jdkBinDirectory`, `sourcePaths`,
`classOutputDirectory`, `libsDirectory`, `jarPath`, `javaDocsPath`,
`resourcePath`, `classPaths`, `fatJarPaths`, `compileOptions`, `jarOptions`,
`encoding`, and `manifest`.# Compile DSL
