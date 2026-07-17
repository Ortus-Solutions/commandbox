# CommandBox Build Process Documentation

This document provides a comprehensive overview of CommandBox's Ant-based build system, including all targets, dependencies, and the complete build workflow.

## Overview

CommandBox uses Apache Ant for its build system with a sophisticated multi-target build process that creates various distribution formats including JAR files, native executables, Linux packages, and embedded JRE distributions.

## Build Architecture

### Build Files Structure

```
build/
├── build.xml                    # Main Ant build file
├── build.properties             # Base build configuration
├── build-auto.properties        # Auto environment config
├── build-ortushq.properties     # OrtusHQ environment config
├── lib/                         # Ant task JARs
│   ├── ant-contrib-1.0b3.jar
│   ├── ant-deb-0.0.1.jar
│   └── maven-ant-tasks-2.1.3.jar
├── resource/                    # Build resources
```

## Key Build Properties

### Version Management

- `commandbox.version`: Current version (e.g., "6.3.0-alpha")
- `commandbox.stableVersion`: Latest stable version (e.g., "6.2.1")
- `isStable`: Boolean flag when version == stableVersion

### Dependencies

- `cfml.version`: Lucee engine version (5.4.6.9)
- `runwar.version`: Runwar JAR version (5.1.3)
- `jline.version`: JLine terminal library (3.21.0)
- `jgit.version`: JGit library version (5.13.3.202401111512-r)
- `jre.version`: Bundled JRE version (jdk-11.0.26+4)

### Build Locations

- `src.dir`: Source directory (../src)
- `lib.dir`: Libraries directory (../lib)
- `temp.dir`: Temporary build directory (${basedir}/temp)
- `dist.dir`: Distribution output (../dist/${commandbox.version})

## Build Targets

### Core Build Targets

#### `init`

- **Purpose**: Initialize build environment
- **Actions**:
  - Cleans temp, build, lib, and dist directories
  - Creates required directory structure
  - Increments build number in `build.number` file
  - Creates version file with `${commandbox.version}+${build.number}`
  - Sets appropriate permissions for staging environments

#### `resolve.libs`

- **Purpose**: Download and resolve all external dependencies
- **Maven Repositories**:
  - Eclipse JGit: `https://repo.eclipse.org/content/groups/releases/`
  - Sonatype Snapshots: `https://oss.sonatype.org/content/repositories/snapshots/`
  - Maven Central: `https://repo1.maven.org/maven2/`
- **Key Dependencies**:
  - JLine terminal library
  - Jansi ANSI support
  - Eclipse JGit for Git operations
  - JCommander for CLI parsing
  - Lucee CFML engine
  - Runwar embedded server
  - CFML extensions from update.lucee.org

#### `build.cli`

- **Purpose**: Build the core CommandBox JAR file
- **Dependencies**: `init`, `resolve.libs`
- **Process**:
  1. Copies resolved libraries to engine destinations
  2. Extracts and modifies Lucee Light core.lco file
  3. Injects CFML extensions into manifest
  4. Re-packages modified Lucee Light JAR
  5. Compiles Java source code from `src/java/`
  6. Creates `box.jar` with embedded CFML engine

### Distribution Targets

#### `build.cli.bin`

- **Purpose**: Create native Unix/Mac binary
- **Dependencies**: `build.cli`
- **Output**: Native `box` executable for Linux/macOS

#### `build.cli.exe`

- **Purpose**: Create Windows executable
- **Dependencies**: `build.cli`
- **Process**:
  - Downloads Launch4J for Windows executable wrapping
  - Creates `box.exe` Windows executable
  - Includes proper Windows metadata and icons

#### `build.cli.jre`

- **Purpose**: Build distributions with embedded JRE
- **Condition**: Only for stable builds (`isStable=true`)
- **Process**:
  - Downloads platform-specific JREs
  - Creates self-contained distributions for:
    - Windows x64 with JRE
    - Linux x64 with JRE
    - macOS x64 with JRE
  - No Java installation required on target systems

#### `build.cli.deb`

- **Purpose**: Create Debian/Ubuntu package
- **Dependencies**: `build.cli.bin`
- **Output**: `.deb` package for Debian-based systems
- **Repositories**: Creates both testing and stable repositories

#### `build.cli.rpm`

- **Purpose**: Create Red Hat/CentOS package
- **Dependencies**: `build.cli.bin`
- **Output**: `.rpm` package for Red Hat-based systems

### Documentation and API Targets

#### `build.apidocs`

- **Purpose**: Generate API documentation
- **Dependencies**: `build.cli.bin`
- **Process**:
  1. Starts temporary CommandBox server
  2. Runs DocBox to generate API docs
  3. Creates public and internal API documentation
  4. Generates ZIP files with checksums (MD5, SHA, SHA-256)

#### `build.homebrew`

- **Purpose**: Generate Homebrew formula
- **Output**: Ruby formula file for macOS Homebrew installation

### Aggregation Targets

#### `build.cli.all`

- **Purpose**: Build all distribution formats
- **Dependencies**: `build.cli.deb`, `build.cli.exe`, `build.cli.jre`, `build.cli.rpm`, `build.apidocs`, `build.homebrew`
- **Environment-specific cleanup**: Removes unnecessary files in automated builds

## Build Workflow

### 1. Environment Setup

```bash
# Local development build
ant -f build/build.xml build.cli

# Production build (all formats)
ant -f build/build.xml build.cli.all
```

### 2. Dependency Resolution

- Maven repositories are queried for latest versions
- JARs downloaded to `lib/` directory
- CFML extensions downloaded from Lucee extension repository
- Platform-specific tools (Launch4J, JRE) downloaded as needed

### 3. Core Compilation

- Java source code compiled from `src/java/`
- CFML system files prepared
- Lucee engine modified with required extensions
- Everything packaged into `box.jar`

### 4. Platform-Specific Packaging

- Native binaries created for Unix/Windows
- Platform installers generated (DEB, RPM)
- JRE-embedded distributions for offline installation

### 5. Quality Assurance

- Checksums generated for all artifacts (MD5, SHA-1, SHA-256)
- GPG signing for production releases
- API documentation generated and validated

## Environment-Specific Builds

### Local Development (`environment=local`)

- Simplified build process
- No JRE embedding
- No package repository updates
- Faster iteration for development

### Automated/CI (`environment=auto`)

- Full build pipeline
- All distribution formats
- Repository updates
- Artifact signing
- Permission management for staging servers

## Testing Integration

### `build.testwar`

- Creates test WAR file for integration testing
- Uses cfdistro build system for CFML web application packaging

### `test`

- Starts test server with CommandBox
- Runs TestBox test suite
- Stops server and reports results

## Build Artifacts

### Primary Artifacts

- `box.jar`: Core CommandBox JAR file
- `box`: Native Unix/macOS executable
- `box.exe`: Windows executable
- `commandbox-{version}.deb`: Debian package
- `commandbox-{version}.rpm`: Red Hat package

### JRE-Embedded Artifacts (Stable builds only)

- `commandbox-{version}-windows-x64.zip`: Windows with JRE
- `commandbox-{version}-linux-x64.tar.gz`: Linux with JRE
- `commandbox-{version}-mac-x64.tar.gz`: macOS with JRE

### Documentation Artifacts

- `commandbox-apidocs-{version}.zip`: Public API documentation
- `commandbox-core-apidocs-{version}.zip`: Internal API documentation

### Repository Artifacts

- Debian repository metadata
- RPM repository metadata
- Maven repository for programmatic access

## Customization Points

### Version Management

Update version numbers in `build.xml`:
```xml
<property name="commandbox.version" value="6.3.0-alpha"/>
<property name="commandbox.stableVersion" value="6.2.1"/>
```

### Dependency Updates

Modify versions in `build.properties`:
```properties
cfml.version=5.4.6.9
runwar.version=5.1.3
jline.version=3.21.0
```

### Environment Configuration

Create environment-specific property files:
- `build-local.properties`
- `build-production.properties`
- Custom environment via `-Denvironment=myenv`

## Security and Signing

### GPG Signing

Production builds include GPG signing using properties:
- `ortus.sign.keyring`: Path to GPG keyring
- `ortus.sign.key.id`: GPG key identifier
- `ortus.sign.key.passphrase`: Key passphrase

### Checksum Generation

All artifacts include multiple checksums:
- MD5 for compatibility
- SHA-1 for Git integration
- SHA-256 for modern security requirements

## Troubleshooting

### Common Issues

1. **Network Dependencies**: All external dependencies require internet access
2. **Platform Tools**: Launch4J and JRE downloads are platform-specific
3. **Memory Requirements**: Large builds may require increased Ant heap size
4. **Permission Issues**: Staging builds require specific file permissions

### Build Verification

Always verify successful builds by checking:
- All expected artifacts in `dist/` directory
- Checksum file integrity
- Native executable functionality
- JAR file manifest correctness