# CommandBox AI Coding Agent Instructions

CommandBox is a CLI tool, package manager, and embedded server that serves both CFML (ColdFusion Markup Language) and BoxLang languages. Built on Java and CFML, it's a complex multi-layered application with a modular architecture.

## Documentation Resources

- **Official Docs**: https://commandbox.ortusbooks.com/
- **Context7 Docs**: https://context7.com/ortus-docs/commandbox-docs

## Architecture Overview

### Core Structure

- **Shell Layer** (`src/cfml/system/Shell.cfc`): Interactive CLI shell with JLine integration
- **Service Layer** (`src/cfml/system/services/`): Singleton services managed by WireBox DI
- **Command Layer** (`src/cfml/system/modules_app/`): Modular command structure organized by domain
- **Java Loader** (`src/java/`): Java bootstrap and classloader for CFML engine integration

### Key Services Pattern

Services are singletons injected via WireBox. Critical services include:
- `ServerService`: Manages embedded CFML servers (Lucee, Adobe CF, BoxLang)
- `PackageService`: Handles ForgeBox packages and dependencies
- `CommandService`: Command discovery, parsing, and execution
- `ConfigService`: Hierarchical configuration management
- `EndpointService`: Pluggable artifact resolution (ForgeBox, HTTP, Git, etc.)

## Command Development Patterns

### Command Structure

Commands extend `BaseCommand` and live in domain-specific modules:
```cfml
// File: src/cfml/system/modules_app/server-commands/commands/server/start.cfc
component extends="commandbox.system.BaseCommand" aliases="start" {
    property name="serverService" inject="ServerService";

    function run() {
        // Command logic using injected services
    }
}
```

### Command Organization

- Commands are organized by domain: `server-commands/`, `package-commands/`, etc.
- Each module has `ModuleConfig.cfc` for ColdBox module configuration
- Command aliases defined in component metadata enable shortcuts

## Development Workflows

### Building

- **Build System**: Ant-based with complex multi-target process (`build/build.xml`)
- **Core Build**: `ant -f build/build.xml build.cli` creates `box.jar`
- **Full Distribution**: `ant -f build/build.xml build.cli.all` creates all formats
- **Key Targets**:
  - `init`: Environment setup and directory structure
  - `resolve.libs`: Download Maven dependencies and CFML extensions
  - `build.cli`: Compile Java + CFML into JAR
  - `build.cli.exe/bin`: Native executables for Windows/Unix
  - `build.cli.jre`: Self-contained distributions with embedded JRE
  - `build.cli.deb/rpm`: Linux package formats
- **Dependencies**: Maven repos for Java libs, ForgeBox for CFML modules
- **Build Documentation**: See `build/BUILD.md` for complete process details

### Testing

- TestBox framework in `tests/` directory
- Run tests via: `box testbox run`
- Test structure mirrors source: `tests/cfml/system/` and `tests/cfml/commands/`

### Module Development

Commands are auto-discovered via WireBox scanning. New commands:
1. Extend `BaseCommand`
2. Place in appropriate domain module
3. Use dependency injection for services
4. Follow existing naming conventions

## Critical Conventions

### Dependency Injection

```cfml
// Standard service injection pattern
property name="serverService" inject="ServerService";
property name="configService" inject="ConfigService";
property name="fileSystem" inject="FileSystem";
```

### Configuration Management

- Global config: `~/.CommandBox/CommandBox.json`
- Server config: `server.json` in project root
- Hierarchical config resolution: CLI args > server.json > global config
- Access via: `configService.getSetting('key.path')`

### File System Abstraction

Always use `fileSystem` service for cross-platform compatibility:
```cfml
fileSystem.resolvePath('./path')
fileSystem.makeDirectory('./path')
```

### Output and Formatting

Use injected `print` service for all output:
```cfml
print.line( "Message" ).toConsole();
print.redLine( "Error message" ).toConsole();
```

### Code Formatting Examples

```cfml
// Correct formatting with required spacing:
if( condition && anotherCondition ) {
    var result = someFunction( param1, param2 );
    arrayAppend( myArray, { "key" : "value" } );
}

// Property alignment:
property name="serverService"     inject="ServerService";
property name="configService"     inject="ConfigService";
property name="fileSystemUtil"    inject="FileSystem";
```

## Server Management Specifics

### Engine Support

CommandBox supports multiple language engines:
- **CFML Engines**: Lucee Server (default), Adobe ColdFusion
- **BoxLang Engine**: Native BoxLang runtime support
- **Custom WAR files**: Any Java-based web application

### Server Lifecycle

1. Server resolution via `serverEngineService.resolveEngine()`
2. Runwar JAR execution with JVM args
3. Configuration injection via `-D` properties
4. Process monitoring and management

## Module System

### Built-in Modules

Core modules in `src/cfml/modules/` are ForgeBox packages:
- `coldbox-cli`: ColdBox framework commands
- `testbox-cli`: TestBox testing commands
- `commandbox-cfformat`: Code formatting
- `commandbox-boxlang`: BoxLang engine support

### Module Loading

Modules auto-registered via:
1. `box.json` dependencies
2. WireBox auto-scanning
3. ColdBox module system integration

## Code Style

### Mandatory Formatting Rules

**ALL CFML code MUST adhere to `.cfformat.json` rules for readability:**
- **Spacing**: Required around all operators, parentheses `()`, brackets `[]`, quotes
- **Padding**: `brackets.padding: true`, `parentheses.padding: true`, `binary_operators.padding: true`
- **Quotes**: Always use double quotes (`strings.quote: "double"`)
- **Alignment**: Consecutive assignments, properties, and parameters must align
- **Max columns**: 120 characters
- **Indentation**: Tabs with 4-space equivalent (`tab_indent: true`, `indent_size: 4`)

### Formatting Commands

```bash
# Format everything
box run-script format

# Start a watcher, type away, save and auto-format for you
box run-script format:watch
```

### Markdown Documentation

**ALL Markdown files MUST adhere to `.markdownlint.json` rules:**
- Follow project-specific markdownlint configuration
- Maximum 2 consecutive blank lines (`no-multiple-blanks.maximum: 2`)
- Inline HTML is allowed for specific formatting needs
- Hard tabs are permitted in this project
- Multiple H1 headings allowed for comprehensive documentation

### Naming Conventions

- Services: PascalCase (e.g., `ServerService`)
- Methods: camelCase
- Properties: camelCase
- Commands: lowercase with hyphens for namespaces

## Integration Points

### Java Integration

**Java Components** (`src/java/`):
- **CLI Loader** (`cliloader/LoaderCLIMain.java`): Bootstrap loader that initializes CFML engine
- **Authentication** (`com/ortussolutions/commandbox/authentication/`): Security components
- **JGit Integration** (`com/ortussolutions/commandbox/jgit/`): Git operations
- **Utilities**: Stream handling, version comparison, BOM detection

**Java Usage in CFML**:
- Extensive Java object creation for file I/O, networking, process management
- JLine library for interactive shell features and command completion
- Runwar JAR for embedded server management and deployment
- Direct Java integration via `createObject('java', 'className')` pattern

### External Dependencies

- ForgeBox: Primary package repository
- GitHub: Secondary artifact source
- Maven repositories: Java dependencies
- Custom endpoints: Pluggable artifact resolution

## Multi-Language Support Notes

CommandBox serves both CFML and BoxLang languages with full feature parity. The current branch `feature/rewrites-boxlang-support` enhances BoxLang integration:
- **BoxLang**: Modern JVM language with CFML compatibility
- **CFML**: Traditional ColdFusion Markup Language
- **Unified CLI**: Same commands work across both languages
- **Engine-specific modules**: `commandbox-boxlang` for BoxLang-specific features
- **Configuration**: Server settings may vary between language engines