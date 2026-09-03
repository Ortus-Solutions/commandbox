# CommandBox Build Process Documentation

This document provides a comprehensive overview of CommandBox build targets, dependencies, and workflows.

## Bootstrap Installers

Build bootstrap installers with `Build.bx`:

```powershell
box task run taskFile=Build.bx target=buildInstallers
```

This produces bundled and thin `box` JAR, Unix, and Windows artifacts in `build/dist`, plus a bundled Linux RPM.

Test the Sign4j signing path against a disposable copy of a Windows executable with:

```powershell
$env:DIGICERT_API_KEY="YOUR_API_KEY"
$env:DIGICERT_CLIENT_CERTIFICATE_BASE64="BASE64_ENCODED_CLIENT_CERTIFICATE"
$env:DIGICERT_KEY_ALIAS="YOUR_KEY_ALIAS"
$env:DIGICERT_HOST="https://clientauth.one.digicert.com"
box task run taskFile=Build.bx target=testSign4jPath binaryPath=build/dist/box.exe sign4jPath=build/launch4j-3.50/launch4j/sign4j/sign4j.exe
```

`testSign4jPath` copies the input binary to `build/temp/sign4j-test/`, decodes the client certificate from `DIGICERT_CLIENT_CERTIFICATE_BASE64` into a temporary runtime file, then runs Sign4j with the bundled Jsign signer. The temporary certificate file is removed after signing. Jsign uses the DigiCert API key, client certificate, host, and key alias to sign the executable. The task verifies the resulting Authenticode status on Windows. A custom `SIGNER_COMMAND` or `signerCommand` may be supplied instead.

On Linux, if `sign4jPath` and `SIGN4J_PATH` are not provided and the default bundled `build/launch4j-3.50/launch4j/sign4j/sign4j` is missing, the build task auto-downloads `launch4j-3.50-linux-x64.tgz` from SourceForge and provisions the `sign4j` binary there.

`buildCliRpm` uses native `rpmbuild` inside the Rocky Linux 8 Docker image. The RPM is built from a generated spec, with the bundled launcher installed as `/usr/bin/box` with `0755` permissions. RPM signing, when configured, also runs inside Docker.

Stage and update RPM repository metadata for the current RPM with:

```powershell
box task run taskFile=Build.bx target=updateRpmRepo
```

By default, the task downloads only `repodata` from
`s3://downloads.ortussolutions.com/RPMS-be/noarch/` into `build/dist/RPMS-be/noarch`. Rocky 8 uses the existing metadata and parses only the current RPM to produce production-compatible `repodata`; historical RPMs and `.repo` convenience files are not downloaded or modified. Stable semantic versions also update `s3://downloads.ortussolutions.com/RPMS/noarch/` in `build/dist/RPMS/noarch`. Pre-release versions update only BE. The task does not upload the staged repositories.

Corrected downloadable Yum/DNF convenience files are kept separately in `build/dist/rpm-repo-files/stable` and `build/dist/rpm-repo-files/be`. The repository update task does not manage these files.

Pass `repoS3Path` and `repoPath` to target another repository when its URL is available:

```powershell
box task run taskFile=Build.bx target=updateRpmRepo repoS3Path=s3://downloads.ortussolutions.com/RPMS-be/noarch/ repoPath=build/dist/RPMS-be/noarch stableRepoS3Path=s3://downloads.ortussolutions.com/RPMS/noarch/ stableRepoPath=build/dist/RPMS/noarch
```

`task run` automatically loads local values from `.env`. Use the following variables locally or provide them from CI:

```text
ORTUS_SIGN_KEYRING_BASE64=
ORTUS_SIGN_KEY_ID=
ORTUS_SIGN_KEY_PASSPHRASE=
```

## Debian Packages and Repositories

Build the Debian package with Docker and stage its repository metadata with:

```powershell
box task run taskFile=Build.bx target=buildCliDeb
box task run taskFile=Build.bx target=updateDebRepo
```

`buildCliDeb` uses `debian:bookworm-slim` and `dpkg-deb`, producing
`build/dist/commandbox-debian-<version>.deb`. `updateDebRepo` always stages the BE
repository at `build/dist/debs-be/noarch`. Stable semantic versions also stage the
stable repository at `build/dist/debs/noarch`; pre-release versions do not.

repository staging downloads only `Packages`, `Packages.gz`, `Release`, and any
existing signatures from S3. It copies in the current package, retains existing
package entries, appends the new entry, and regenerates the Debian metadata with `dpkg-scanpackages`,
`gzip`, and `apt-ftparchive`. Historical `.deb` files are not downloaded, and the
staged repositories are not uploaded.

Repository signing uses the same `.env` values documented above. The base64 keyring
is decoded to `build/temp/signing-keyring.gpg` for the Docker signing step and removed
afterward. When all three values are present, `updateDebRepo` creates `Release.gpg`;
otherwise, it stages unsigned metadata for local validation.

## API Documentation

Generate the API documentation with:

```powershell
box task run taskFile=Build.bx target=buildApiDocs
```

`buildApiDocs` generates two documentation sets via DocBox into
`build/dist/apidocs/`:

- `commandbox/{version}/`: Public command documentation
- `commandbox-core/{version}/`: Internal core API documentation

Both sets are also zipped into `build/dist/commandbox-apidocs-{version}.zip` and
`build/dist/commandbox-core-apidocs-{version}.zip` with checksums. The unzipped
HTML is preserved under `build/dist/apidocs/` so it can be synced to the
`apidocs.ortussolutions.com` S3 bucket.

Sync the generated HTML to S3 with:

```powershell
box task run taskFile=Build.bx target=syncApiDocsToS3
```

This uploads the versioned doc folders to the `apidocs.ortussolutions.com` bucket.
When the current version is a stable release, it also uploads the redirect
`index.html` files to `commandbox/current/` and `commandbox-core/current/` so the
docs site always points at the latest stable version. The redirect templates live
in `build/resource/apidocs-commandbox-current-index.html` and
`build/resource/apidocs-commandbox-core-current-index.html` and contain an
`@VERSION@` placeholder that is replaced with the build version before upload.
Pre-release versions (e.g. `6.4.0-alpha`) skip the `current` redirect upload.

Both tasks require `AWS_ACCESS_KEY` and `AWS_ACCESS_SECRET` to be configured.

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
- `jre.version`: Legacy Ant JRE version setting; the active `Build.bx` resolves the latest Liberica Java 21 release at build time.

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
- **Implementation**: `Build.bx` target `buildCliDeb`, using Docker `debian:bookworm-slim` and `dpkg-deb`
- **Output**: `build/dist/commandbox-debian-<version>.deb`

Use `updateDebRepo` to stage BE and, for stable versions, stable Debian repository metadata.

#### `build.cli.rpm`

- **Purpose**: Create Red Hat/CentOS package
- **Implementation**: `Build.bx` target `buildCliRpm`, using Rocky Linux 8 Docker and `rpmbuild`
- **Output**: `build/dist/commandbox-rpm-<version>.rpm`

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
- `apidocs/commandbox/{version}/`: Unzipped public API documentation for the apidocs S3 bucket
- `apidocs/commandbox-core/{version}/`: Unzipped internal API documentation for the apidocs S3 bucket

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

Production builds use these `.env` values for GPG signing:
- `ORTUS_SIGN_KEYRING_BASE64`: Base64-encoded binary GPG keyring
- `ORTUS_SIGN_KEY_ID`: GPG key identifier
- `ORTUS_SIGN_KEY_PASSPHRASE`: Key passphrase

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