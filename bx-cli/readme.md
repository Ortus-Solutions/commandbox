```bash
    ______                                          ______
   / ____/___  ____ ___  ____ ___  ____ _____  ____/ / __ )____  _  __
  / /   / __ \/ __ `__ \/ __ `__ \/ __ `/ __ \/ __  / __  / __ \| |/_/
 / /___/ /_/ / / / / / / / / / / / /_/ / / / / /_/ / /_/ / /_/ />  <
 \____/\____/_/ /_/ /_/_/ /_/ /_/\__,_/_/ /_/\__,_/_____/\____/_/|_| (R)
```

# bx-cli BoxLang Installation

This package is a new form of CommandBox called `bx-cli` which runs on BoxLang and is meant to be installed as a BoxLang module into your BoxLang home.
It currently requires
* BoxLang 1.10.0-snapshot
* the latest `commandbox-boxlang` CommandBox module

It will eventually ship with BoxLang, but for now, you can install it with CommandBox, or manually into your BoxLang home.  To ensure executable registration
works, ensure the `bin` folder in your BoxLang home (probably `~/.boxlang/bin`) is added to your OS `PATH` env var. All of our BoxLang installers should do this
for you soon.

Invoke `bx-cli` as
```
boxlang cli
```
Once you've launched it, you can add a `box` alias like so
```
boxlang cli executable create box "boxlang cli"
```
and then run it as `box` from there on out.  

`bx-cli` will use your previous CommandBox home, if you have one. This means all your
* modules
* servers
* server JREs
* artifacts
* config
* history

will be preserved. In fact, you can share the CommandBox home between a CommandBox 6.x installation and `bx-cli` (7.0-alpha) installation at the same time.

THIS IS ALPHA SO THERE WILL BE ISSUES STILL.  Please report any issues.

## Known issues
* CFLint module uses Lucee-specific OSGI helper and does not work
* Any task runners which have Lucee-specific code will not work as we're now powered by BoxLang

Modules I've done some testing with (they load without error):

* cb-module-template
* commandbox-fusionreactor
* commandbox-http-command
* testbox-cli
* commandbox-cfconfig
* wheels-cli
* commandbox-service-manager@ortus
* commandbox-bookmarks
* coldbox-cli
* commandbox-cfformat 
* commandbox-hostupdater 
* commandbox-dotenv
* commandbox-boxlang 
* contentbox-cli
* commandbox-docbox
* box-ngrok
* commandbox-bullet-train
* commandbox-update-check

# WELCOME TO COMMANDBOX

CommandBox CLI, Package Manager, Embedded CFML Server, REPL and much more!

* Trademark + Copyright since 2014 by [Ortus Solutions, Corp](https://www.ortussolutions.com)
* [All products by Ortus Solutions](https://www.ortussolutions.com/products)
* HONOR GOES TO GOD ABOVE ALL FOR HIS WISDOM FOR THIS PROJECT

**Official Releases**

Official stable releases can be found at the [CommandBox Official Page](https://www.ortussolutions.com/products/commandbox#download)

**Snapshot Releases**

Download from the [Ortus Download Site](https://downloads.ortussolutions.com/#/ortussolutions/commandbox/).

*Just please note that this contains latest bleeding edge releases that might not be stable.*

**Getting Started Guide**

Get going with CommandBox in a matter of minutes with our [Getting Started Guide](https://commandbox.ortusbooks.com/getting-started-guide)

**Bug Tracker**

Found an issue? Check out [Bug Tracker](https://ortussolutions.atlassian.net/jira/software/c/projects/COMMANDBOX/issues)

## DOCUMENTATION

View our latest installation, usage, and development docs here:
[General Docs](https://commandbox.ortusbooks.com/)

View our latest Command API Docs here:
[General Docs](https://apidocs.ortussolutions.com/commandbox/current)

## VERSIONING

CommandBox is maintained under the Semantic Versioning guidelines as much as possible.

Releases will be numbered with the following format:

```bash
<major>.<minor>.<patch>
```

And constructed with the following guidelines:

* Breaking backward compatibility bumps the major (and resets the minor and patch)
* New additions without breaking backward compatibility bumps the minor (and resets the patch)
* Bug fixes and misc changes bumps the patch

## COMMANDBOX LICENSE

CommandBox is open source and bound to the Apache License, Version 2.0 Copyright & TradeMark since 2014, Ortus Solutions, Corp

This program is free software: you can redistribute it and/or modify it under the terms of the Apache License as published by the Apache Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the APACHE LICENSE for more details.

## CREDITS & CONTRIBUTIONS

I have included some software from other open source projects and I have used some code from open source projects in this framework. If I have forgotten to name someone, please send me an email about it.

I THANK GOD FOR HIS WISDOM FOR THIS PROJECT

## Community and Support
Join us in our Ortus Community and become a valuable member of this project [Commandbox CLI](https://community.ortussolutions.com/c/communities/commandbox/14). We are looking forward to hearing from you!
