# Maven Endpoint

CommandBox includes native support for resolving and installing JAR dependencies from Maven
repositories. Use the `maven:` endpoint to pull Java libraries and their transitive dependencies
directly into your CommandBox environment without a separate build tool.

## Endpoint ID format

```
maven:[repo|]groupId:artifactId[:version][?flag=value&flag=value]
```

| Part         | Required | Description                                                                              |
| ------------ | -------- | ----------------------------------------------------------------------------------------- |
| `repo`       | No       | A registered repo alias (e.g. `sonatype`) or a full URL. Followed by a pipe `\|`.          |
| `groupId`    | Yes      | The Maven groupId (dotted, e.g. `org.apache.commons`).                                    |
| `artifactId` | Yes      | The Maven artifactId (dashed, e.g. `commons-lang3`).                                      |
| `version`    | No       | An exact version, a semver range, or omitted for the latest stable release (`STABLE`).    |
| flags        | No       | Optional `key=value` pairs separated by `&`, query-string style, prefixed with `?`. See below. |

### Examples

```bash
# Latest stable version from any registered repo
install maven:org.apache.commons:commons-lang3

# Explicit exact version
install maven:org.apache.commons:commons-lang3:3.14.0

# Version ranges (see "Version handling" below for shell-escaping caveats)
install maven:io.undertow:undertow-core:2.3.x
install maven:io.undertow:undertow-core:~2.3.0
install maven:io.undertow:undertow-core:^2.3.0

# Force resolution from a specific registered repo alias only
install maven:sonatype|org.apache.commons:commons-lang3:3.14.0

# Force resolution from a specific URL only
install maven:https://repo1.maven.org/maven2/|org.apache.commons:commons-lang3:3.14.0

# Skip transitive dependency resolution — install just this one jar
install "maven:io.undertow:undertow-core:2.3.19.Final?transitive=false"
```

## Repo resolution

When the endpoint ID includes a `repo` segment (alias or URL), **only** that repo is consulted.
The user asked for it specifically — a mirror is a transport/performance concern, never a source
of different bytes for the same coordinates (see "Artifact cache" below for why). We do not fall
back to other repos if the requested one doesn't have the artifact.

When the endpoint ID omits `repo`, CommandBox walks the list of registered repos in order and
uses the first one that returns the artifact. A `404` (or any lookup failure) on one repo just
moves us to the next. Use `install --verbose` to see the resolution trail, e.g.:

```
Resolving Maven artifact from registered repos
Trying repo [mavenCentral]
  Resolved from repo [mavenCentral]
```

Repos come from three sources, merged in order (later sources override same-named earlier ones):

1. **Built-in default**: `mavenCentral` is always registered.
2. **Global config**: `endpoints.maven.repositories` (see below).
3. **Project `box.json`**: `maven.repositories` (see below).

## Registering repos

### Globally (applies to every CLI session)

```bash
config set endpoints.maven.repositories.sonatype="https://oss.sonatype.org/content/repositories/releases/"
config set endpoints.maven.repositories.jitpack="https://jitpack.io/"
```

Verify with:

```bash
config show endpoints.maven
```

Or edit `~/.CommandBox/CommandBox.json` directly (prefer `config set` over hand-editing — it's
easy to corrupt a large JSON config file by hand):

```json
{
  "endpoints": {
    "maven": {
      "repositories": {
        "sonatype":         "https://oss.sonatype.org/content/repositories/releases/",
        "jitpack":          "https://jitpack.io/",
        "google":           "https://maven.google.com/",
        "spring":           "https://repo.spring.io/release/",
        "jboss":            "https://repository.jboss.org/nexus/content/repositories/releases/",
        "apacheSnapshots":  "https://repository.apache.org/snapshots/",
        "gradlePlugins":    "https://plugins.gradle.org/m2/"
      }
    }
  }
}
```

Struct insertion order is preserved — repos are tried in the order they appear. `mavenCentral`
is always tried first unless you redefine it here with a different URL.

### Per project (checked in with your code)

Add a nested `maven.repositories` key to your project's `box.json` — same shape as the global
config setting (`endpoints.maven.repositories`), just without the `endpoints` prefix:

```json
{
  "name": "my-project",
  "version": "1.0.0",
  "maven": {
    "repositories": {
      "mavenCentral": "https://maven-central.storage.googleapis.com/maven2/",
      "jitpack":      "https://jitpack.io/"
    }
  },
  "dependencies": {}
}
```

A per-project entry with the same alias name as a global (or built-in) entry overrides its URL —
tested by pointing `mavenCentral` at a bogus URL in a project `box.json` and confirming
CommandBox tried the bogus URL first, then correctly fell through to the next registered repo
after it failed. Per-project entries not present globally are simply appended to the list.

## Version handling

### Default: `STABLE`

Omitting the version resolves to the artifact's `<release>` from `maven-metadata.xml`
(Maven's own designation for "the current latest non-snapshot version"). If `<release>` is
missing, CommandBox falls back to scanning `<versions>` and picking the highest non-SNAPSHOT
entry. SNAPSHOT versions are always excluded from `STABLE` resolution.

### Exact versions

Any version that satisfies `semver.isExactVersion()` (e.g. `3.14.0`, `2.0.0.Final`, `1.0-M1`)
is treated as immutable and short-circuits directly to the artifact cache when present —
**zero network calls** for a repeat install of an already-cached exact version.

### Semver ranges

Use the same syntax as ForgeBox / npm. All the following are tested and working:

```
2.3.x                    # x-range — highest 2.3.*
~2.3.0                   # tilde-range — highest 2.3.* (patch-level flexibility)
^2.3.0                   # caret-range — highest 2.x.x >= 2.3.0
>=2.3.0 <2.4.0           # explicit bound range
```

CommandBox fetches the repo's `maven-metadata.xml`, filters out SNAPSHOTs, sorts descending,
and picks the highest matching version.

#### ⚠️ Windows shell escaping caveats

Typing ranges directly on a Windows command line hits some real, pre-existing shell quirks that
have nothing to do with CommandBox — they affect **any** batch-file-based CLI tool:

- **`<` and `>` are recognized by `cmd.exe` even inside double quotes** (unlike `|`, which
  quoting does protect). PowerShell invoking `box` — a `.bat` file — goes through `cmd.exe`
  under the hood, so `install "maven:foo:bar:>=1.0 <2.0"` will break apart into separate
  redirected commands no matter how you quote it from PowerShell or `cmd.exe` directly.
  **Workaround:** use the range in a project `box.json`'s `dependencies` (no shell parsing
  involved at all), or use `^<`/`^>` if invoking from a raw `cmd.exe` prompt (not PowerShell).
- **`^` is `cmd.exe`'s own escape character** and gets stripped even inside quotes. A caret
  range typed directly (`^2.3.0`) will arrive as `2.3.0` (caret silently removed) when going
  through `cmd.exe`. Prefer `~` or `x`-ranges when typing directly on Windows, or put the
  caret range in `box.json` instead.
- **A bare `=` in any CLI argument is parsed by CommandBox's own tokenizer** as a named
  parameter (`key=value`) — this is intentional, documented CommandBox behavior (it's what
  lets you type `box echo text=brad`), and it is **independent of the OS shell**. If you need
  a literal `=` inside a positional argument (e.g. our `?flag=value` syntax below), escape it
  as `\=`.
- **A bare `|` is CommandBox's own command-chaining operator** (`cmd1 | cmd2`), also
  independent of the OS shell. As long as the `|` and everything around it arrives as a
  single OS-level argument (i.e. properly quoted for your shell), CommandBox will NOT split
  on it — its chain-detector only splits when a token is *exactly* `|`, not when `|` merely
  appears inside a larger string. This matters for the optional `repo|` prefix.
- **A bare `?` by itself is CommandBox's own help shortcut** (`install ?` shows help), but this
  only applies when `?` is the *entire* final token of a command — never when `?` is embedded
  inside a larger quoted string like our `?flag=value` syntax below.

**Bottom line:** for anything beyond simple exact-version or x-range/tilde-range installs,
prefer putting the dependency in your project's `box.json` rather than fighting shell quoting
on the command line.

### Maven-style ranges (in POMs only)

When parsing a downloaded POM's transitive dependencies, CommandBox translates Maven's
bracket notation into the semver equivalent before storing them in the child `box.json`:

| Maven          | Semver              |
| -------------- | ------------------- |
| `[1.0,2.0)`    | `>=1.0 <2.0`        |
| `(1.0,2.0]`    | `>1.0 <=2.0`        |
| `[1.0]`        | (exact) `1.0`       |

## Per-install flags

Append `?key=value&key=value` after the version, query-string style, to override default
resolution behavior for a single install. Flags are parsed independently of the repo prefix —
you can combine both:

```
maven:sonatype|org.example:foo:1.0?scopes=runtime,compile,test
```

| Flag         | Default            | Description                                                        |
| ------------ | ------------------- | -------------------------------------------------------------------- |
| `scopes`     | `runtime,compile`  | Comma-separated list of Maven scopes to include as transitives.     |
| `snapshots`  | `false`             | Allow SNAPSHOT versions when resolving `STABLE` / ranges.           |
| `optional`   | `false`             | Include `<optional>true</optional>` transitive dependencies.        |
| `transitive` | `true`              | Set `false` to install just the requested jar, skipping dep resolution. |
| `exclude`    | (none)              | Comma-separated `groupId:artifactId` pairs to exclude from transitive resolution. |
| `installMode` | `dedicated`       | Use `shared` to bundle the artifact and its transitives into the caller's shared install directory. |
| `classifier` | (none)             | Select a JAR variant such as `sources`, `javadoc`, `tests`, or `debug`. |

### JAR classifiers

Use `classifier` to request a published JAR variant:

```json
{
  "dependencies": {
    "undertow-sources": "maven:io.undertow:undertow-core:2.3.18.Final?classifier=sources&transitive=false"
  }
}
```

This resolves `undertow-core-2.3.18.Final-sources.jar`. If the requested classifier is not
published for the selected version, installation fails; CommandBox does not silently fall back to
the unclassified JAR.

### Maven install modes

Maven installs use `dedicated` mode by default. In dedicated mode, each artifact is installed in
its own package directory with its generated `box.json`, allowing normal package version tracking,
dependency trees, and updates.

Use `shared` mode when several JARs should be bundled into one directory such as `libs/`:

```json
{
  "maven": {
    "installMode": "shared",
    "installDirectory": "libs/"
  }
}
```

`maven.installDirectory` overrides the normal JAR install convention for every Maven artifact,
including transitives. It applies to both `shared` and `dedicated` installs. In shared mode, all
JARs are placed directly in that directory. In dedicated mode, it is the base directory for the
artifact's package directory and its nested dependencies.

Install-mode precedence is:

1. Endpoint flag: `?installMode=shared`
2. Project `box.json`: `maven.installMode`
3. Global configuration: `endpoints.maven.installMode`
4. Default: `dedicated`

Configure the global default with:

```bash
config set endpoints.maven.installMode=shared
```

Configure a global Maven JAR destination with:

```bash
config set endpoints.maven.installDirectory=libs
```

Project `maven.installDirectory` takes precedence over `endpoints.maven.installDirectory`. When
neither setting is present, Maven leaves the directory unset and lets the normal JAR convention
apply: shared installs use the caller's directory, while dedicated installs use `lib/`.

Shared mode still creates temporary package metadata, so Maven transitives can be resolved and
installed through the normal CommandBox dependency flow. The generated `box.json` is not copied
to the shared destination, and transitive dependencies are not persisted into that destination's
`box.json`.

For shared installs, each generated transitive resolves to the same shared destination. Dedicated
installs instead give each transitive its own `groupId-artifactId` directory beneath its parent
artifact directory.

### Flag examples

Every example below (except `snapshots`, see note) was installed for real and verified against
the resulting `lib/` folder.

**`scopes`** — `org.jboss.threads:jboss-threads:3.9.2` normally excludes its `test`-scoped deps.
Adding `test` to the scope list pulls them in:

```json
{
  "dependencies": {
    "jboss-threads": "maven:org.jboss.threads:jboss-threads:3.9.2?scopes=runtime,compile,test"
  }
}
```

Tested: correctly installs `junit-jupiter`, `assertj-core`, `awaitility`, and `jboss-logmanager`
(all `test`-scoped in the POM) in addition to the normal runtime/compile deps.

**`optional`** — `ch.qos.logback:logback-classic:1.2.13` declares `javax.mail:mail`,
`org.codehaus.janino:janino`, and `javax.servlet:javax.servlet-api` as `<optional>true</optional>`:

```json
{
  "dependencies": {
    "logback-classic": "maven:ch.qos.logback:logback-classic:1.2.13?optional=true"
  }
}
```

Tested: with the flag, all three optional deps are installed alongside `logback-core` and
`slf4j-api`. Without the flag (the default), none of the three optional deps appear.

**`transitive`** — install just the one jar, skip dependency resolution entirely:

```json
{
  "dependencies": {
    "undertow-core": "maven:io.undertow:undertow-core:2.3.19.Final?transitive=false"
  }
}
```

Tested: only `io.undertow-undertow-core` appears under `lib/` — none of its normal transitive
dependencies (`xnio-nio`, `wildfly-common`, etc.) are installed.

**`exclude`** — omit a specific transitive dependency (and it stays excluded no matter how deep
it would otherwise reappear in the tree):

```json
{
  "dependencies": {
    "jboss-threads": "maven:org.jboss.threads:jboss-threads:3.9.2?exclude=org.jboss.logging:jboss-logging"
  }
}
```

Tested: `jboss-logging` never appears under `lib/`, including several levels deep under
`wildfly-common` — confirmed the exclusion is carried onto `wildfly-common`'s own generated
endpoint ID as resolution recurses.

**`snapshots`** — allow `STABLE`/range resolution to pick a `SNAPSHOT` version instead of only
ever picking the latest non-snapshot release:

```json
{
  "dependencies": {
    "spring-core": "maven:springSnapshots|org.springframework:spring-core:STABLE?snapshots=true&transitive=false"
  },
  "maven": {
    "repositories": {
      "springSnapshots": "https://repo.spring.io/snapshot/"
    }
  }
}
```

This registers Spring's snapshot repository and resolves `spring-core` to its latest available
snapshot. `transitive=false` keeps the example focused on snapshot version selection by installing
only the requested JAR.

### Combining flags

Multiple flags combine with `&`, same as a URL query string. Example: allow the optional deps of
`logback-classic`, but still exclude two specific ones:

```json
{
  "dependencies": {
    "logback-classic": "maven:ch.qos.logback:logback-classic:1.2.13?optional=true&exclude=javax.mail:mail,org.codehaus.janino:janino"
  }
}
```

Tested: only `javax.servlet-api` (the one remaining optional dep) is installed alongside
`logback-core` and `slf4j-api` — `javax.mail:mail` and `org.codehaus.janino:janino` are both
correctly excluded despite `optional=true` re-enabling optional deps in general.

### How `exclude` propagates

Excludes come from two sources, merged together at every level of the tree:

- **Your own `?exclude=` flag** — applies uniformly to the *entire* subtree. It's automatically
  re-stamped onto every generated transitive dependency's own endpoint ID as resolution recurses,
  so it keeps taking effect no matter how deep the excluded artifact would otherwise appear.
- **POM-native `<exclusions>`** — some libraries declare their own exclusions on a specific
  dependency edge (e.g. "when I depend on X, don't pull in Y from X's graph"). CommandBox reads
  these directly from the POM and merges them in automatically — no flag needed. Unlike your own
  `?exclude=`, a POM-declared exclusion only applies to that one dependency's own subtree, not its
  siblings, matching real Maven semantics.

Tested end-to-end: installing `org.jboss.threads:jboss-threads:3.9.2?exclude=org.jboss.logging:jboss-logging`
correctly omits `jboss-logging` everywhere in the tree, including from `wildfly-common` several
levels deep — confirmed the exclusion is carried on `wildfly-common`'s own generated endpoint ID.

### Escaping flags on the CLI

Since a bare `=` is CommandBox's own named-parameter syntax (see above), **escape it as `\=`**
when typing an endpoint ID with flags directly:

```bash
# Tested and working:
box install "maven:io.undertow:undertow-core:2.3.19.Final?transitive\=false"
```

**Combining multiple flags with `&` on Windows is unreliable from the CLI.** Just like `<`/`>`/`^`
(see the shell-escaping caveats above), `cmd.exe` can mangle a bare `&` even inside quotes when
PowerShell invokes the `box.bat` wrapper — it's `cmd.exe`'s own command-separator character.
A single flag (`?transitive\=false`) is reliable; combining several
(`?scopes\=runtime,compile,provided&optional\=true`) is not, on Windows. **Use a project `box.json`
for anything with more than one flag.**

box.json dependencies don't need any escaping at all — CommandBox's tokenizer never touches
raw JSON string values:

```json
{
  "dependencies": {
    "undertow-core": "maven:io.undertow:undertow-core:2.3.19.Final?transitive=false",
    "druid": "maven:com.alibaba:druid:1.2.5?scopes=runtime,compile,provided&optional=true"
  }
}
```

## Artifact cache

Maven JARs are verified against the repository's `.sha256` checksum when available, falling back
to `.sha1`. This verification applies to network downloads and artifacts copied from the local
Maven repository. Installation fails if a checksum is missing or does not match.

Downloaded artifacts are stored under `~/.CommandBox/artifacts/`. The cache key is:

```
maven-<groupId>--<artifactId>/<version>/<key>.zip
```

The cache is keyed **purely by `groupId:artifactId:version` (GAV)** — the repo that served it is
**not** part of the key, matching real Maven/Gradle local-repository semantics. Maven Central's
publishing rules guarantee a given GAV is immutable and byte-identical everywhere, so which repo
(or mirror) happened to serve it is irrelevant to the cache. This also means once an artifact is
cached from a trusted repo, a later untrusted/rogue repo entry can't silently shadow it on a
repeat install. The `maven-` prefix namespaces our cache keys against other endpoints (ForgeBox,
GitHub, etc.) that share the same artifact cache directory.

The cache stores the resolved artifact, not a permanent installation layout. On every cache hit,
CommandBox rehydrates its generated descriptor with the current install mode and install directory,
including its transitive dependency paths. A previous dedicated install therefore cannot cause a
later shared install to create nested artifact directories, and vice versa.

**Cache is only used for exact versions** — `STABLE` and ranges always consult the remote
`maven-metadata.xml` to know which concrete version to resolve to (then re-check the cache
against that concrete version before downloading, so a repeat `STABLE` install of an
already-resolved version still costs only one metadata fetch, not a re-download).

### Local Maven repository fallback (`~/.m2/repository`)

After checking our own artifact cache (and before downloading anything over the network),
CommandBox also checks your local Maven repository at `~/.m2/repository` — the same folder
real Maven, most Java IDEs, and other JVM tooling already download into. If the exact GAV
you're installing is already sitting there, CommandBox copies it straight from disk instead
of downloading it again:

```
Resolved from repo [mavenCentral]
Found in local Maven repository cache (~/.m2/repository) - skipping download: C:\Users\...\logback-classic-1.2.13.jar
Storing download in artifact cache...
Done.
```

Notes:

- **Read-only** — CommandBox never writes to `~/.m2/repository`. It's purely an additional,
  already-populated local source worth checking.
- **Only used for exact versions**, same as our own cache — Maven's local repository has no
  concept of "latest" or ranges, just concrete `groupId/artifactId/version` folders on disk.
- Once used, the artifact is copied into CommandBox's own artifact cache, so subsequent
  installs hit our cache directly and never touch `~/.m2` again.
- Any error checking `~/.m2/repository` (missing folder, permissions, unusual mounts, etc.) is
  silently ignored — this is a best-effort convenience check and never blocks or fails an
  install.
- This does **not** apply to metadata/POM fetches — those still consult your registered repos
  over the network as normal.

## Transitive dependency resolution

CommandBox reads the artifact's `.pom`, walks the `<parent>` chain (up to 10 levels deep,
with cycle detection), and produces a flat list of transitive dependencies. Each transitive
is written into the parent artifact's generated `box.json` as a plain `maven:` endpoint ID
**without** a pinned repo — so each transitive is free to resolve independently from the
artifact cache or any registered repo.

### What's filtered out

- **`test` / `provided` / `system` scope** — only `compile` and `runtime` are installed by
  default (override with the `scopes` flag above).
- **`<optional>true</optional>` deps** — Maven marks these as non-transitive; we honor it
  by default (override with the `optional` flag above).
- **Excluded groupId:artifactId pairs** — from your own `?exclude=` flag (propagated to the
  whole subtree) and/or the POM's own `<exclusions>` declarations (scoped to that one dependency
  edge). See "Per-install flags" above.
- **Deps with no resolvable version** — after `<dependencyManagement>` inheritance from
  the entire parent chain, any dep still missing a version is skipped rather than guessed.

### `<dependencyManagement>` handling

Entries in `<dependencyManagement>` are **not** installed themselves. They are collected
into a lookup map (merged across the parent chain, with child POM entries shadowing parents)
and used solely to fill in missing `<version>` / `<scope>` / `<type>` on real `<dependencies>`
elsewhere in the same POM.

### Property placeholder resolution

`${...}` placeholders in POM values are resolved by walking the parent chain:

- `${project.groupId}`, `${project.version}`, `${project.artifactId}` (and the deprecated
  `${pom.*}` aliases) — resolved against the current POM, falling back to its `<parent>`
  element, then to each ancestor's own field, in order.
- Custom `<properties>` — looked up across the chain (child properties shadow parent).
- Unresolved placeholders are left as-is; the caller decides what to do.

## Network behavior

- All XML metadata/POM fetches (`maven-metadata.xml`, `.pom` files, parent POMs) use a
  20-second timeout, so a hung repo doesn't stall an install indefinitely.
- Every network call checks `offlineMode` first and fails fast with a clear message
  (`config set offlineMode=false` to go back online) rather than timing out.
- The endpoint still works fully offline for already-cached exact versions — no network
  calls happen at all in that case. The same is true if the exact version is found in your
  local Maven repository (`~/.m2/repository`) — no network call is needed for the jar itself.
- JAR downloads are delegated to the `jar:` endpoint, which uses CommandBox's progressable
  downloader (progress bar, cancellable, offline-aware) rather than a raw HTTP call.

## Verbose output

```bash
install maven:io.undertow:undertow-core --verbose
```

Shows every repo attempted, cache hits (`Lucky you, we found this version in local artifacts!`),
downloads, POM parent walks, and dependency resolution.

## Known limitations

- **POM `<repositories>` are not consulted.** Some POMs declare additional repos in a
  `<repositories>` block for their own dependency resolution. CommandBox does not currently
  read or honor these — only the repos you've explicitly registered (built-in, global config,
  or project `box.json`) are consulted. Planned as an opt-in feature gated behind an
  `endpoints.maven.trustPomRepositories` setting (default `false`), since blindly trusting a
  POM's own repo declarations is a supply-chain risk (a compromised dependency could point at
  a rogue repo for a sibling artifact).
- **BOM imports** (`<scope>import</scope>` `<type>pom</type>` inside `<dependencyManagement>`)
  are not fully processed yet — CommandBox does not fetch imported BOMs to merge their
  `<dependencyManagement>` into the current resolution. Most real-world artifacts still
  resolve correctly because their direct dependencies carry their own versions.
- **Classifier and type on transitive dependencies** (e.g. `<classifier>sources</classifier>`,
  `<type>war</type>`) are parsed but not yet honored during download — transitive resolution
  fetches the primary `.jar`. The endpoint-level `classifier` flag remains supported for a
  requested artifact.
- **Only one JAR is fetched per endpoint ID.** CommandBox does not automatically download
  associated sources, javadocs, or test artifacts; request one explicitly with the `classifier`
  flag when it is published.
