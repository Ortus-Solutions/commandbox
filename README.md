``` bash
   _____                                          _ ____            
  / ____|                                        | |  _ \           
 | |     ___  _ __ ___  _ __ ___   __ _ _ __   __| | |_) | _____  __
 | |    / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |  _ < / _ \ \/ /
 | |___| (_) | | | | | | | | | | | (_| | | | | (_| | |_) | (_) >  < 
  \_____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|____/ \___/_/\_\ 
```

# WELCOME TO COMMANDBOX 

CommandBox CLI, Package Manager, REPL and much more!

* v1.0.0.@build.number@
* Trademark + Copyright since 2014 by Ortus Solutions, Corp
* <http://www.ortussolutions.com>
* [All products by Ortus Solutions](http://www.ortussolutions.com/products)
* HONOR GOES TO GOD ABOVE ALL

## COMMANDBOX INSTALLATION

More details will be coming soon regarding IVY/Maven/cfdistro package managers. Commands downloads and installs the needed resources by default into your user home directory under .CommandBox automatically.

**Direct download**

Download executable from here [jar, bin, win32](http://cfmlprojects.org/artifacts/com/ortussolutions/box.cli/1.0.0/)
Run executable

**Package repository for REDHAT based Linux:**

Add the following to: /etc/yum.repos.d/box.repo
``` bash
[box]
name=Box $releasever - $basearch
failovermethod=priority
baseurl=http://cfmlprojects.org/artifacts/RPMS/noarch
enabled=1
metadata_expire=7d
gpgcheck=0
```
Then run:
``` bash
sudo yum update; sudo yum install box-cli
```

**Install repository for DEBIAN based Linux**

Add the following to: /etc/apt/sources.list.d/box.list
``` bash
deb http://cfmlprojects.org/artifacts/debs/ ./
```
Then run: 
``` bash
sudo apt-get update; sudo apt-get install box-cli
```

**Compile from github source**

Clone into your preferred commands directory:
``` bash
git clone https://github.com/webmandman/box-cli.git
```
Initial build:
``` bash
cd box-cli
``` 
or for windows:
``` bash
sudo ./box-cli build
```
``` bash
box-cli.bat build
```
Build executable:
``` bash
sudo ./box-cli build.cli.bin
```
or for windows:
``` bash
box-cli.bat build.cli.exe
```
After you build your preferred executable, cd into the newly created dist folder and execute the box command, which will look like this:
``` bash
YourComputer:dist user$ ./box

  _____                                          _ ____
 / ____|                                        | |  _ \
| |     ___  _ __ ___  _ __ ___   __ _ _ __   __| | |_) | _____  __
| |    / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |  _ < / _ \ \/ /
| |___| (_) | | | | | | | | | | | (_| | | | | (_| | |_) | (_) >  <
 \_____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|____/ \___/_/\_\ v1.0.0.00002

Welcome to CommandBox!
Type "help" for help, or "help [command]" to be more specific.
CommandBox>
```

**Run tests**

If you'd like to run the tests for CI, etc., run:
``` bash
sudo ./box-cli build.test
```
or for windows:
``` bash
box-cli.bat build
```

**Run a test server**

If you'd like to run the test server continually for IDE development, which will start a server on port 8088 and wait for the ctrl-c to terminate, run:
``` bash
sudo ./box-cli runwar.start.fg
```

## COMMANDBOX USAGE

You can run CommandBox in interactive CLI mode, or server mode.  To run in interactive mode, simply type "box".  To run the server, type "box -server".

Type "box help", or "help" at the CommandBox> prompt to get a list of available commands. Type "help [command]" for in-depth descriptions.

## CREATE YOUR OWN COMMANDS

CommandBox is extensible via CFML by creating command CFCs.  Any CFC in the '${box.home}/commands' directory will be registered as a command as long as it extends 'commandbox.system.BaseCommand' and has a 'run()' method. 

To create a two-part command called "testbox run" create CFCs that are nested in subfolders, for example: 
${box.home}/commands/testbox/run.cfc. Everything after the command is considered parameters.

All CFC's are wired via WireBox, so dependency injection is available to them.

Tab completion and help are powered by metadata on these CFCs. If you would like to use a friendlier name for your command, add the attribute "aliases" to the component which is a comma-delimited list of names.

Here is the command `dir` briefly explained:
``` javascript
/**
 * Lists the files and folders in a given directory.  Defaults to current working directory
 *
 * dir samples
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="ls,ll,directory" excludeFromHelp=false {

	/**
	 * @directory.hint The directory to list the contents of
	 * @recurse.hint recursively list
	 **/
	function run( String directory="", Boolean recurse=false )  {
		// command code goes here
	}
}
``` 

## COMMANDBOX DEVELOPMENT

To hack on the sources, there are two main approaches.

The easiest is to install CommandBox, then cd into the {install-directory}/dist directory, and finally run:
``` bash
./box execute ./src/cfml/system/Bootstrap.cfm
```
This will load the source version of the shell, instead of the included one.  
Make any changes you want to the commands in {install-directory}/src/cfml directory, and then at the CommandBox> prompt run "reload", which will load your changes.

The second way is to build the test server and run the tests through the IDE or
the TestBox facade:

"./box-cli build.testwar" (builds the test war)
"./box-cli runwar.start.fg" (starts the test server)

Browse to: "http://127.0.0.1:8088/tests/{path/to/test/cfc/to/run}"


## VERSIONING

CommandBox is maintained under the Semantic Versioning guidelines as much as possible.

Releases will be numbered with the following format:

<major>.<minor>.<patch>

And constructed with the following guidelines:

* Breaking backward compatibility bumps the major (and resets the minor and patch)
* New additions without breaking backward compatibility bumps the minor (and resets the patch)
* Bug fixes and misc changes bumps the patch

## COMMANDBOX LICENSE

CommandBox is open source and bound to the LGPL v3 GNU LESSER GENERAL PUBLIC LICENSE Copyright & TradeMark since 2014, Ortus Solutions, Corp

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

## CREDITS & CONTRIBUTIONS

I have included some software from other open source projects and I have used some code from open source projects in this framework. If I have forgotten to name someone, please send me an email about it.

I THANK GOD FOR HIS WISDOM FOR THIS PROJECT

## THE DAILY BREAD

"I am the way, and the truth, and the life; no one comes to the Father, but by me (JESUS)" Jn 14:1-12
