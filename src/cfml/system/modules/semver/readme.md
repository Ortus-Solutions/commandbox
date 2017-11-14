# Semantic Version

This is a library that implements npm-style semantic versioning for CFML.

* Semantic version: major.minor.revision-preReleaseID+build
* http://semver.org/
* https://github.com/npm/node-semver

## Usage
```
var semver = wirebox.getInstance( 'semanticVersion@semver' );
semver.satisfies( '1.0.0', '1.0.x' );
```