# Ship Java JARs Right From Your CommandBox CLI

Need to compile Java sources and ship a JAR? You've got options — Gradle, Maven, Ant — and they're all great at what they do. But for a CFML developer, firing up a whole build toolchain to package a bit of Java is overkill, and none of them feel familiar. CommandBox can now compile your Java sources, package them into JARs, generate Javadocs, and even merge everything into a single runnable "fat" JAR — all from one command, or from a fluent DSL inside your task runners.

Under the hood, CommandBox locates your JDK, globs your `.java` files, drives `javac`, and then runs the JAR tool to package the result. No JDK installed? CommandBox will download Java 21 for you and get out of your way.

> **Note:** This feature is currently available only in the **bx-cli beta** builds of CommandBox, not the current stable releases. Give it a spin and let us know what you think!

## Sensible Defaults

The Compile DSL follows Gradle's standard conventions out of the box — your sources, resources, classes, JARs, and Javadocs land exactly where a Gradle developer would expect them. And every single path is configurable.

| Setting | Default | Gradle equivalent |
| --- | --- | --- |
| Java sources | `src/main/java` | `src/main/java` |
| Resources | `src/main/resources` | `src/main/resources` |
| Compiled classes | `build/classes/java/main` | `build/classes/java/main` |
| JAR output | `build/libs` | `build/libs` |
| Javadocs | `build/docs/javadoc` | `build/docs/javadoc` |

## 1. Just Compile

Feed it a source folder, get back classes. That's the whole example.

File structure you feed in:

```js
src/
└── main/
    └── java/
        └── example/
            └── Hello.java
```

Task runner DSL:

```js
compile().run();
```

The same thing at the shell:

```js
java compile
```

Output — your compiled classes land in the default output directory:

```js
build/
└── classes/
    └── java/
        └── main/
            └── example/
                └── Hello.class
```

## 2. Build a JAR

One extra method call (or one extra flag) and you get a JAR in `build/libs`.

Task runner DSL:

```js
var result = compile()
	.toJar( "hello.jar" )
	.run();

print.line( result.jarPath ); // build/libs/hello.jar
```

Shell equivalent:

```js
java compile --jar jarName=hello.jar
```

You get a JAR at `build/libs/hello.jar` (and your compiled classes in `build/classes/java/main`).

## 3. Custom Layout & Compiler Options

Non-standard project? Point the DSL anywhere and pass real `javac` options as a struct.

File structure you feed in:

```js
src/
└── custom/
    └── java/
        └── com/
            └── myapp/
                └── Main.java
```

Task runner DSL:

```js
compile()
	.fromSource( "src/custom/java" )
	.toClasses( "target/classes" )
	.libsDir( "dist" )
	.compileOptions( {
		"release"    : 8,
		"debug"      : [ "lines", "source" ],
		"encoding"   : "UTF-8",
		"parameters" : true
	} )
	.toJar( "myapp.jar" )
	.run();
```

Shell equivalent:

```js
java compile source=src/custom/java classes=target/classes libsDir=dist --jar jarName=myapp.jar compileOptions:release=8 compileOptions:debug=lines,source compileOptions:encoding=UTF-8 compileOptions:parameters=true
```

Output:

```js
target/
└── classes/
    └── com/
        └── myapp/
            └── Main.class
dist/
└── myapp.jar
```

## 4. Manifest Entries & Resources

Bundle a `Main-Class`, version metadata, and resource files straight into the archive. Resources from `src/main/resources` are included automatically with their directory structure preserved.

File structure you feed in:

```js
src/
└── main/
    ├── java/
    │   └── example/
    │       └── App.java
    └── resources/
        └── config.properties
```

Task runner DSL:

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

Shell equivalent:

```js
java compile --jar jarName=example.jar manifest:Main-Class=example.App manifest:Implementation-Version=1.2.3 manifest:Implementation-Title="Example Application"
```

Output — what ends up inside the JAR:

```js
example.jar
├── example/
│   └── App.class
├── config.properties
└── META-INF/
    └── MANIFEST.MF
```

Bonus: if your project has a `box.json`, its metadata (name, version, author, homepage, license, and more) is used to populate the manifest automatically. An explicit `manifest:` call always wins over it.

## 5. Classpaths & Javadocs

Need dependency JARs on the compile classpath, or want documentation generated? Both are one-liners.

Task runner DSL:

```js
compile()
	.withClassPath( "libs" )
	.withJavaDocs()
	.toJar( "example.jar" )
	.run();
```

Shell equivalent:

```js
java compile classPath=libs --javaDocs --jar jarName=example.jar
```

You get your JAR at `build/libs/example.jar` and Javadocs in `build/docs/javadoc`.

## 6. The Showstopper: Fat JARs

This is the one that gets people excited. Hand the DSL your dependency JARs and it merges them into a single runnable uber-JAR — combining `META-INF/services` provider files and stripping dependency signature files so the result actually runs.

File structure you feed in:

```js
src/
└── main/
    └── java/
        └── example/
            └── App.java
libs/
└── dependencies/
    ├── gson-2.10.1.jar
    └── slf4j-api-2.0.9.jar
```

Task runner DSL:

```js
compile()
	.withClassPath( "libs/dependencies" )
	.toFatJar(
		jarName    = "app-all.jar",
		includeJars = [ "libs/dependencies" ]
	)
	.run();
```

Shell equivalent:

```js
java compile classPath=libs/dependencies --fatJar fatJarName=app-all.jar fatJarJars=libs/dependencies
```

Output — the project JAR plus the merged fat JAR, side by side:

```js
build/
└── libs/
    ├── app.jar       ← your project JAR
    └── app-all.jar   ← everything merged in
```

Ship the fat JAR anywhere with a JRE:

```js
java -jar build/libs/app-all.jar
Hello from your fat JAR!
```

Tune the merge behavior — service-descriptor merging, signature exclusion, and the duplicate-entry policy (`last`, `first`, or `error`) — with `configureFatJar()` in the DSL or `fatJarOptions:` flags on the command line.

## Everything You Need, Returned To You

`run()` hands back an object with every path and option used, which makes the DSL ideal for scripting and CI pipelines:

```js
var result = compile()
	.toJar( "example.jar" )
	.run();

result.projectRoot          // where you ran the command/task
result.jdkBinDirectory      // path to the JDK bin folder
result.sourcePaths          // [ "src/main/java" ]
result.classOutputDirectory // build/classes/java/main
result.libsDirectory        // build/libs
result.jarPath              // build/libs/example.jar
result.resourcePath         // src/main/resources
result.manifest             // the manifest entries that were applied
```

Prefer that from the CLI? Add `--JSON` and the command prints and returns the same object without the human-readable summary.

## The Whole Lifecycle: init → compile → run

Put it all together and a brand-new project goes from nothing to running in three commands:

```js
java init              // scaffold folders + write the java config to box.json
java compile           // build the JAR
java run               // execute it
```

`java init` stubs a `Hello, World!` class and sets it as the main class in box.json, so `java run` works with zero arguments. And `java run` understands box.json completely — override the entry point, the JAR, the classpath, or the Java version on the fly:

```js
java run mainClass=com.foo.App
java run javaVersion=17
java run :1=arg1 :2=arg2
```

## Next Steps

- Run `java compile --help` inside CommandBox for the full list of options
- Point the DSL at another project with `compile( "path/to/project" ).toJar( "thing.jar" ).run()`
- Curious how deep this goes? CommandBox dogfoods it — the CLI's own launcher JAR is built with this very DSL in the build script

Give it a spin — your next JAR is a single command away.
