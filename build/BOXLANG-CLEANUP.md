# Deferred cleanup — waiting on BoxLang

This file tracks product cleanup work that is **blocked on BoxLang runtime fixes**, so the
follow-up doesn't get lost. Delete the relevant section once done.

---

## 1. Remove `ortus-java.jar` (the last custom compiled Java helper)

**Status:** blocked on a BoxLang capability fix.
**Owner of the fix:** BoxLang runtime (`JavaMethodResolver` / protected-method override stubs).

### Background

As part of the JGit `5.13.3` -> `7.3.0` upgrade, all of CommandBox's custom JGit Java glue was
removed and reimplemented in CFML:

- `com.ortussolutions.commandbox.jgit.CommandCaller` -> native BoxLang `e.cause` walking
- `com.ortussolutions.commandbox.jgit.SSHCallback` + `GenericSessionFactory`
  -> `src/cfml/system/util/JGitSSHCallback.cfc` (`createDynamicProxy` + Apache MINA sshd config),
  plus `src/cfml/system/util/JGitAcceptAllServerKeyDatabase.cfc` for host key acceptance

What remains is a single compiled class:

```text
src/java/com/ortussolutions/commandbox/authentication/ProxyAuthenticator.java
```

which is compiled into `ortus-java.jar` by the `run()` target in `Build.bx` and shipped in the
`bx-cli` module `libs/` folder.

### Why it can't be CFML yet

`ProxyAuthenticator` extends `java.net.Authenticator` and overrides:

```java
protected PasswordAuthentication getPasswordAuthentication()
```

`java.net.Authenticator` is a **JDK** class, so class loading is fine — the problem is that
BoxLang does not generate a stub for an override of a **`protected`** Java method, so the JDK
keeps calling the parent implementation instead of ours.

Verified behaviour — a public override dispatches, a protected one does not:

```text
public  label()      = overridden-by-BoxLang     <- public override dispatches correctly
protected via parent = hello from parent         <- protected override is IGNORED
direct greet()       = BoxLang-greet-override    <- direct call from BoxLang works (misleading)
```

A pure-BoxLang `Authenticator` subclass registers fine via `Authenticator.setDefault()` and
answers a *direct* call, but the JDK round-trip
(`Authenticator.requestPasswordAuthentication(...)`) returns `null` instead of invoking the
override. Only the JDK calls it in production, so the class cannot move to CFML yet.

Upstream cause (per BoxLang investigation): `JavaMethodResolver.isOverridable` only accepts
`public`, so a BoxLang UDF matching a protected Java method gets no generated stub.

### Work to do once BoxLang is fixed

1. Create a BoxLang replacement, e.g. `src/cfml/system/util/ProxyAuthenticator.cfc`:

   ```cfml
   component extends="java:java.net.Authenticator" {

       function init( required string user, required string password ) {
           variables.user     = arguments.user;
           variables.password = arguments.password;
           return this;
       }

       function getPasswordAuthentication() {
           return createObject( "java", "java.net.PasswordAuthentication" ).init(
               variables.user,
               createObject( "java", "java.lang.String" ).init( variables.password ).toCharArray()
           );
       }

   }
   ```

2. Update `src/cfml/system/util/ProgressableDownloader.cfc`, which currently does:

   ```cfml
   var proxyAuthenticator = createObject( 'java', 'com.ortussolutions.commandbox.authentication.ProxyAuthenticator').init( proxyUser, proxyPassword )
   ```

   to use the CFML component instead.
3. Delete `src/java/com/ortussolutions/commandbox/authentication/ProxyAuthenticator.java`.
4. Remove the `compile()` step in `Build.bx` (the one targeting `build/temp/classes/ortus-java`
   producing `ortus-java.jar`), and drop `src/java/com` entirely if nothing else remains there.
5. Remove `ortus-java.jar` from the module `libs/`.
6. Verify HTTP downloads through an authenticated proxy still work.

### Verification

```bash
box install git+https://github.com/Ortus-Solutions/commandbox-cfconfig.git
```

plus an HTTP artifact download with a proxy user configured.

---

## BoxLang issues found during this work

Three *separate* behaviours were found. Only the second blocks the cleanup above. All three
belong in a BoxLang bug report rather than this repo — they are listed here so the context isn't
lost. Each is a minimal, copy-pasteable reproduction.

### 1. `extends="java:..."` fails for jars loaded from the BoxLang home `lib/` folder

Extending a JAR-supplied Java class works when the jar is on the **application** classpath, but
fails with `ClassInfo not found for <class>` when the same jar is loaded from the BoxLang home
`lib/` folder. This does not block the cleanup above (`java.net.Authenticator` is a JDK class),
but it does affect module `libs/` jars generally.

Given `libs/parent.jar` containing `com/example/Parent.class`, and `Child.bx`:

```text
class extends="java:com.example.Parent" {
}
```

| Jar placement                        | Result |
| ------------------------------------ | ------ |
| BoxLang home `lib/` folder           | `ClassInfo not found for com.example.Parent` |
| Application classpath (`-classpath`) | works |

The class is resolvable either way via `createObject( "java", "com.example.Parent" )`, so it is a
compiler/loader visibility gap rather than a hard capability limit.

### 2. `protected` methods are never overridden

This is the blocker for the cleanup above. `JavaMethodResolver.isOverridable` only accepts
`public`, so a BoxLang UDF matching a `protected` Java method gets no generated stub.

With a Java parent exposing one `public` method (`label()`) and one `protected` method
(`greet()`, invoked from Java via a public `callGreet()`), a BoxLang subclass overriding both:

```text
public  label()      = overridden-by-BoxLang     <- dispatches to the BoxLang override
protected via parent = hello from parent         <- the Java parent's body still runs
direct greet()       = BoxLang-greet-override    <- direct calls work, which is misleading
```

### 3. `add()` through to a Java super class fails (regression)

Unrelated to the two above, and not present in the Oct 7 `boxlang-1.0.1` build — it reproduces on
`development` HEAD. `size()`, `isEmpty()` and `get(int)` work, but overloads needing argument
coercion (`add(Object)`, `add(int, Object)`) report `Method 'add' not found`.
