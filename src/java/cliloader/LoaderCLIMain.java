/**
 * Copyright (C) 2012 Ortus Solutions, Corp
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3.0 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library.
 */
package cliloader;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileReader;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintStream;
import java.io.PrintWriter;
import java.lang.reflect.Method;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLClassLoader;
import java.net.URLDecoder;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Properties;

import net.minidev.json.JSONArray;

public class LoaderCLIMain{
	
	public static class ExtFilter implements FilenameFilter{
		private final String	ext;

		public ExtFilter( String extension ){
			this.ext = extension;
		}

		@Override
		public boolean accept( File dir, String name ){
			return name.toLowerCase().endsWith( this.ext );
		}
	}

	private static class log{
		public static void debug( String message ){
			if( debug ) {
				System.out.println( message.replace( "/n", CR ) );
			}
		}

		public static void error( String message ){
			System.err.println( message.replace( "/n", CR ) );
		}

		public static void warn( String message ){
			System.out.println( message.replace( "/n", CR ) );
		}
	}

	public static class PrefixFilter implements FilenameFilter{
		private final String	prefix;

		public PrefixFilter( String prefix ){
			this.prefix = prefix;
		}

		@Override
		public boolean accept( File dir, String name ){
			return name.toLowerCase().startsWith( this.prefix );
		}
	}

	private static URLClassLoader	_classLoader;
	private static String			CFML_VERSION_PATH		= "cliloader/cfml.version";
	private static String			CFML_ZIP_PATH			= "cfml.zip";
	private static ClassLoader		classLoader				= Thread.currentThread()
																	.getContextClassLoader();
	private static File				CLI_HOME;
	private static String			CR						= System.getProperty(
																	"line.separator" )
																	.toString();
	private static Boolean			debug					= false;
	private static String			ENGINECONF_ZIP_PATH		= "engine.zip";
	private static int				exitCode				= 0;
	private static Boolean			isBackground;
	private static String			LIB_ZIP_PATH			= "libs.zip";
	private static File				libDirectory;
	private static File				luceeConfigServerDirectory,
			luceeConfigWebDirectory, luceeCLIConfigServerDirectory,
			luceeCLIConfigWebDirectory;
	private static String			name;
	private static String			serverName				= "default";

	private static String			shellPath;

	private static String			VERSION_PROPERTIES_PATH	= "cliloader/version.properties";

	private static File				webRoot;

	public static String arrayToList( String[] s, String separator ){
		String result = "";
		if( s.length > 0 ) {
			result = s[ 0 ];
			for( int i = 1; i < s.length; i++) {
				result += separator + s[ i ];
			}
		}
		return result;
	}

	private static void execute( ArrayList< String > cliArguments )
			throws ClassNotFoundException, NoSuchMethodException,
			SecurityException, IOException{
		log.debug( "Running in CLI mode" );
		System.setIn( new NonClosingInputStream( System.in ) );
		String uri = null;
		if( new File( getCLI_HOME(), getShellPath() ).exists() ) {
			uri = new File( getCLI_HOME(), getShellPath() ).getCanonicalPath();
		} else if( new File( getShellPath() ).exists() ) {
			uri = new File( getShellPath() ).getCanonicalPath();
		} else {
			log.error( "Could not find shell:" + getShellPath() );
			exitCode = 1;
			return;
		}
		if( cliArguments.size() > 1 && cliArguments.contains( "execute" ) ) {
			// bypass the shell for running pure CFML files
			int executeIndex = cliArguments.indexOf( "execute" );
			File cfmlFile = new File( cliArguments.get( executeIndex + 1 ) );
			if( cfmlFile.exists() ) {
				uri = cfmlFile.getCanonicalPath();
			}
			cliArguments.remove( executeIndex + 1 );
			cliArguments.remove( executeIndex );
			log.debug( "Executing: " + uri );
		} else if( cliArguments.size() > 0
				&& new File( cliArguments.get( 0 ) ).isFile() ) {
			String filename = cliArguments.get( 0 );
			// this will force the shell to run the execute command
			if( filename.endsWith( ".rs" ) || filename.endsWith( ".boxr" ) ) {
				log.debug( "Executing batch file: " + filename );
				cliArguments.add( 0, "recipe" );
			} else {
				File cfmlFile = new File( filename );
				if( cfmlFile.exists() ) {
					log.debug( "Executing file: " + filename );
					uri = cfmlFile.getCanonicalPath();
					cliArguments.remove( 0 );
				}
			}
			// handle bash script
			uri = removeBinBash( uri );
		} else {
			if( debug ) {
				System.out.println( "uri: " + uri );
			}
		}

		System.setProperty(
				"cfml.cli.arguments",
				arrayToList( cliArguments.toArray( new String[ cliArguments
						.size() ] ), " " ) );
		System.setProperty(
				"cfml.cli.argument.list",
				arrayToList( cliArguments.toArray( new String[ cliArguments
						.size() ] ), "," ) );
		JSONArray jsonArray = new JSONArray();
		jsonArray.addAll( cliArguments );
		System.setProperty( "cfml.cli.argument.array", jsonArray.toJSONString() );
		if( debug ) {
			System.out.println( "cfml.cli.arguments: "
					+ Arrays.toString( cliArguments.toArray() ) );
		}
		if( debug ) {
			System.out.println( "cfml.cli.argument.array: "
					+ jsonArray.toJSONString() );
		}

		InputStream originalIn = System.in;
		PrintStream originalOut = System.out;

		URLClassLoader cl = getClassLoader();
		try {
			Class< ? > cli;
			cli = cl.loadClass( "luceecli.CLIMain" );
			Method run = cli.getMethod( "run", new Class[] { File.class,
					File.class, File.class, String.class, boolean.class } );
			File webroot = new File( getPathRoot( uri ) ).getCanonicalFile();
			run.invoke( null, webroot, getLuceeCLIConfigServerDir(),
					getLuceeCLIConfigWebDir(), uri, debug );
		} catch ( Exception e ) {
			exitCode = 1;
			e.printStackTrace();
			if( e.getCause() != null ) {
				System.out.println( "Cause:" );
				e.getCause().printStackTrace();
			}
		}
		cl.close();
		System.out.flush();
		System.setOut( originalOut );
		System.setIn( originalIn );
	}

	private static URLClassLoader getClassLoader(){
		if( _classLoader == null ) {
			File libDir = getLibDir();
			File[] children = libDir.listFiles( new ExtFilter( ".jar" ) );
			ArrayList< File > jars = new ArrayList< File >();
			if( children.length < 2 ) {
				libDir = new File( libDir, "lib" );
				setLibDir( libDir );
				children = libDir.listFiles( new ExtFilter( ".jar" ) );
			}
			if( children == null || children.length < 2 ) {
				System.out.println( "Could not find libraries" );
				System.exit( 1 );
			}

			for( File jar : children) {
				jars.add( jar );
				if( !jar.getName().contains( "runwar" ) ) {
				}
			}
			URL[] urls = new URL[ jars.size() ];
			if( debug ) {
				System.out.println( "Loading Jars" );
			}
			for( int i = 0; i < jars.size(); i++) {
				try {
					urls[ i ] = jars.get( i ).toURI().toURL();
					if( debug ) {
						System.out.println( "- " + urls[ i ] );
					}
				} catch ( MalformedURLException e ) {
					e.printStackTrace();
				}
			}
			URLClassLoader libsLoader = new URLClassLoader( urls, classLoader );
			_classLoader = libsLoader;
		}
		return _classLoader;
	}

	private static File getCLI_HOME(){
		return CLI_HOME;
	}

	private static File getCLI_HOME( ArrayList< String > cliArguments,
			Properties props, String[] arguments, Map< String, String > config ){
		File cli_home = null;
		String name = getName();
		String home = name + "_home";
		if( getCLI_HOME() == null ) {
			Map< String, String > env = System.getenv();
			log.debug( "home: checking for command line argument " + home );
			if( mapGetNoCase( config, home ) != null ) {
				String homeArg = mapGetNoCase( config, home );
				if( homeArg.length() == 0 ) {
					System.err.println( "The home directory cannot be empty" );
					System.exit( 1 );
				}
				cli_home = new File( homeArg );
				arguments = removeElement( arguments, "-" + home );
				listRemoveContaining( cliArguments, "-" + home );
			}
			if( cli_home == null ) {
				File cliPropFile = new File( getJarDir(), getName()
						.toLowerCase() + ".properties" );
				if( !cliPropFile.isFile() ) {
					cliPropFile = new File( getJarDir(), "cli.properties" );
				}
				if( cliPropFile.isFile() ) {
					Properties userProps = new Properties();
					FileInputStream fi;
					try {
						log.debug( "checking for home in properties from "
								+ cliPropFile.getCanonicalPath() );
						fi = new FileInputStream( cliPropFile );
						userProps.load( fi );
						fi.close();
						if( mapGetNoCase( userProps, "cli.home" ) != null ) {
							cli_home = new File( mapGetNoCase( userProps,
									"cli.home" ) );
						} else if( mapGetNoCase( userProps, home ) != null ) {
							cli_home = new File( mapGetNoCase( userProps, home ) );
						}
					} catch ( IOException e ) {
						e.printStackTrace();
					}
				}
			}
			if( cli_home == null ) {
				log.debug( "home: checking for environment variable" );
				if( mapGetNoCase( env, home ) != null ) {
					cli_home = new File( mapGetNoCase( env, home ) );
				}
			}
			if( cli_home == null ) {
				log.debug( "home: checking for system property" );
				if( mapGetNoCase( System.getProperties(), home ) != null ) {
					cli_home = new File( mapGetNoCase( System.getProperties(),
							home ) );
				}
			}
			if( cli_home == null ) {
				log.debug( "home: checking cli.properties" );
				if( mapGetNoCase( props, home ) != null ) {
					cli_home = new File( mapGetNoCase( props, home ) );
				} else if( mapGetNoCase( props, "cli.home" ) != null ) {
					cli_home = new File( mapGetNoCase( props, "cli.home" ) );
				}
			}
			if( cli_home == null ) {
				log.debug( "home: using default" );
				String userHome = System.getProperty( "user.home" );
				if( userHome != null ) {
					cli_home = new File( userHome + "/." + name + "/" );
				} else {
					cli_home = new File( LoaderCLIMain.class
							.getProtectionDomain().getCodeSource()
							.getLocation().getPath() ).getParentFile();
				}
			}
		}
		setCLI_HOME( cli_home );
		log.debug( "home: " + cli_home.getAbsolutePath() );
		return cli_home;
	}

	private static String getCurrentDir(){
		return System.getProperty( "user.dir" );
	}

	private static String getJarDir(){
		String path = new File( LoaderCLIMain.class.getProtectionDomain()
				.getCodeSource().getLocation().getPath() ).getParent();
		new java.net.URLDecoder();
		// Decode things like spaces in folders which will be %20
		return URLDecoder.decode( path );
	}

	private static File getLibDir(){
		return libDirectory;
	}

	private static File getLuceeCLIConfigServerDir(){
		return luceeCLIConfigServerDirectory;
	}

	private static File getLuceeCLIConfigWebDir(){
		return luceeCLIConfigWebDirectory;
	}

	private static File getLuceeConfigServerDir(){
		return luceeConfigServerDirectory;
	}

	private static File getLuceeConfigWebDir(){
		return luceeConfigWebDirectory;
	}

	private static String getName(){
		return name;
	}

	public static String getPathRoot( String string ){
		return string.replaceAll( "^([^\\\\//]*?[\\\\//]).*?$", "$1" );
	}

	private static String getServerName(){
		return serverName == null ? "default" : serverName;
	}

	private static String getShellPath(){
		return shellPath;
	}

	private static File getWebRoot(){
		return webRoot;
	}

	private static Boolean isBackground(){
		return isBackground;
	}

	public static boolean listContains( ArrayList< String > argList, String text ){
		// check for args with "--" too
		if( listIndexOf( argList, text ) != -1
				|| listIndexOf( argList, "-" + text ) != -1 ) {
			return true;
		}
		return false;
	}

	public static int listIndexOf( ArrayList< String > argList, String text ){
		int index = 0;
		for( String item : argList) {
			if( item.startsWith( text ) || item.startsWith( "-" + text ) ) {
				return index;
			}
			index++;
		}
		return -1;
	}

	public static void listRemoveContaining( ArrayList< String > argList,
			String text ){
		for( Iterator< String > it = argList.iterator(); it.hasNext();) {
			String str = it.next();
			// check for "--" too
			if( str.toLowerCase().startsWith( text.toLowerCase() )
					|| str.toLowerCase().startsWith( '-' + text.toLowerCase() ) ) {
				it.remove();
			}
		}
	}

	@SuppressWarnings( "static-access" )
	public static void main( String[] arguments ) throws Throwable{
		Util.ensureJavaVersion();
		System.setProperty( "apple.awt.UIElement", "true" );
		ArrayList< String > cliArguments = new ArrayList< String >(
				Arrays.asList( arguments ) );
		File cli_home;
		Boolean updateLibs = false;
		Boolean startServer = false;
		Boolean stopServer = false;
		Properties props = new Properties(), userProps = new Properties();
		if( listContains( cliArguments, "-debug" ) ) {
			debug = true;
			listRemoveContaining( cliArguments, "-debug" );
			arguments = removeElement( arguments, "-debug" );
		}
		try {
			props.load( ClassLoader
					.getSystemResourceAsStream( "cliloader/cli.properties" ) );
		} catch ( IOException e ) {
			e.printStackTrace();
		}
		log.debug( "initial arguments:" + Arrays.toString( arguments ) );
		Map< String, String > config = toMap( arguments );
		String name = props.getProperty( "name" ) != null ? props
				.getProperty( "name" ) : "lucee";
		setName( name );

		// merge any user defined properties
		File cliPropFile = new File( getJarDir(), getName().toLowerCase()
				+ ".properties" );
		if( !cliPropFile.isFile() ) {
			cliPropFile = new File( getJarDir(), "cli.properties" );
		}
		if( cliPropFile.isFile() ) {
			log.debug( "merging properties from "
					+ cliPropFile.getCanonicalPath() );
			FileInputStream fi = new FileInputStream( cliPropFile );
			userProps.load( fi );
			fi.close();
			props = mergeProperties( props, userProps );
		}

		log.debug( "cfml.cli.name: " + name );
		setShellPath( props.getProperty( "shell" ) != null ? props
				.getProperty( "shell" ) : "/cfml/cli/shell.cfm" );

		cli_home = getCLI_HOME( cliArguments, props, arguments, config );
		arguments = removeElement( arguments, "-" + getName() + "_home" );

		log.debug( "initial cfml.cli.home: " + cli_home );
		if( !cli_home.exists() ) {
			System.out.println( "Configuring " + name + " home: " + cli_home
					+ " (change with -" + name + "_home=/path/to/dir)" );
			cli_home.mkdir();
		}

		if( new File( cli_home, "cli.properties" ).isFile() ) {
			FileInputStream fi = new FileInputStream( new File( cli_home,
					"cli.properties" ) );
			userProps.load( fi );
			fi.close();
			props = mergeProperties( props, userProps );
		} else {
			// userProps.put("cfml.cli.home", cli_home.getAbsolutePath());
			// FileOutputStream fo = new FileOutputStream(new
			// File(cli_home,"cli.properties"));
			// userProps.store(fo,null);
		}

		// update/overwrite libs
		if( listContains( cliArguments, "-update" ) ) {
			System.out.println( "updating " + name + " home" );
			updateLibs = true;
			listRemoveContaining( cliArguments, "-update" );
			arguments = removeElement( arguments, "-update" );
		}

		setLibDir( new File( cli_home, "lib" ).getCanonicalFile() );

		// background
		if( listContains( cliArguments, "-background" ) ) {
			setBackground( true );
			arguments = removeElement( arguments, "-background" );
		} else {
			setBackground( false );
		}

		if( listContains( cliArguments, "-stop" ) ) {
			stopServer = true;
			setBackground( false );
		}

		if( listContains( cliArguments, "-name" ) ) {
			setServerName( config.get( "name" ) );
			log.debug( "Set server name to" + getServerName() );
			arguments = removeElement( arguments, "-name" );
			listRemoveContaining( cliArguments, "-name" );
		}

		if( !updateLibs
				&& ( listContains( cliArguments, "-?" ) || listContains(
						cliArguments, "-help" ) ) ) {
			System.out.println( props.get( "usage" ).toString()
					.replace( "/n", CR ) );
			Thread.sleep( 1000 );
			System.exit( 0 );
		}

		// lucee libs dir
		if( listContains( cliArguments, "-lib" ) ) {
			String strLibs = config.get( "lib" );
			setLibDir( new File( strLibs ) );
			arguments = removeElementThenAdd( arguments, "-lib=", null );
			listRemoveContaining( cliArguments, "-lib" );
		}

		if( listContains( cliArguments, "-server" ) ) {
			startServer = true;
		}

		if( listContains( cliArguments, "-webroot" )
				&& config.get( "webroot" ) != null ) {
			arguments = removeElement( arguments, "-webroot" );
			setWebRoot( new File( config.get( "webroot" ) ).getCanonicalFile() );
		} else {
			if( getCurrentDir() != null ) {
				setWebRoot( new File( getCurrentDir() ).getCanonicalFile() );
			} else {
				setWebRoot( new File( "./" ).getCanonicalFile() );
			}
		}

		if( listContains( cliArguments, "-shellpath" ) ) {
			int shellpathIdx = listIndexOf( cliArguments, "-shellpath" );
			String shellpath = cliArguments.get( shellpathIdx );
			if( shellpath.indexOf( '=' ) == -1 ) {
				setShellPath( cliArguments.get( shellpathIdx + 1 ) );
				cliArguments.remove( shellpathIdx + 1 );
				cliArguments.remove( shellpathIdx );
			} else {
				setShellPath( shellpath.split( "=" )[ 1 ] );
				cliArguments.remove( shellpathIdx );
			}
			arguments = removeElement( arguments, "-shellpath" );
		}
		props.setProperty( "cfml.cli.shell", getShellPath() );

		if( listContains( cliArguments, "-shell" ) ) {
			startServer = false;
			log.debug( "we will be running the shell" );
			arguments = removeElement( arguments, "-shell" );
			listRemoveContaining( cliArguments, "-shell" );
		}

		File libDir = getLibDir();
		props.setProperty( "cfml.cli.lib", libDir.getAbsolutePath() );
		File cfmlDir = new File( cli_home.getPath() + "/cfml" );

		// clean out any leftover pack files (an issue on windows)
		Util.cleanUpUnpacked( libDir );

		if( libDir.exists() ) {
			File versionFile = new File( libDir, "version.properties" );
			if( !versionFileMatches( versionFile, VERSION_PROPERTIES_PATH ) ) {
				String autoUpdate = props.getProperty( "cfml.cli.autoupdate" );
				if( autoUpdate != null && Boolean.parseBoolean( autoUpdate ) ) {
					log.warn( "\n*updating installed version" );
					updateLibs = true;
					versionFile.delete();
				} else {
					log.warn( "run '" + name
							+ " -update' to install new version" );
				}
			}
		}

		if( !libDir.exists()
				|| libDir.listFiles( new ExtFilter( ".jar" ) ).length < 2
				|| updateLibs ) {
			System.out.println( "Library path: " + libDir );
			System.out
					.println( "Initializing libraries -- this will only happen once, and takes a few seconds..." );
			Util.removePreviousLibs( libDir );
			Util.unzipInteralZip( classLoader, LIB_ZIP_PATH, libDir, debug );
			Util.unzipInteralZip( classLoader, CFML_ZIP_PATH, cfmlDir, debug );
			Util.unzipInteralZip( classLoader, ENGINECONF_ZIP_PATH, new File(
					cli_home.getPath() + "/engine" ), debug );
			Util.copyInternalFile( classLoader, "resource/trayicon.png",
					new File( libDir, "trayicon.png" ) );
			Util.copyInternalFile( classLoader, "resource/traymenu.json",
					new File( libDir, "traymenu.json" ) );
			Util.copyInternalFile( classLoader, VERSION_PROPERTIES_PATH,
					new File( libDir, "version.properties" ) );
			System.out.println( "" );
			System.out.println( "Libraries initialized" );
			if( updateLibs && arguments.length == 0 ) {
				System.out.println( "updated " + cli_home + "!" );
				// System.out.println("updated! ctrl-c now or wait a few seconds for exit..");
				// System.exit(0);
			}
			Util.cleanUpUnpacked( libDir );
		}
		// check cfml version
		if( cfmlDir.exists() ) {
			File versionFile = new File( cfmlDir, ".version" );
			if( !versionFileMatches( versionFile, CFML_VERSION_PATH ) ) {
				String autoUpdate = props.getProperty( "cfml.cli.autoupdate" );
				if( autoUpdate != null && Boolean.parseBoolean( autoUpdate ) ) {
					log.warn( "\n*updating installed CFML" );
					versionFile.delete();
					Util.unzipInteralZip( classLoader, CFML_ZIP_PATH, cfmlDir,
							debug );
				} else {
					log.warn( "run '" + name + " -update' to install new CFML" );
				}
			}
		}

		File configServerDir = new File( libDir.getParentFile(),
				"engine/cfml/server/" );
		File configWebDir = new File( libDir.getParentFile(),
				"engine/cfml/server/cfml-web/" + getServerName() );
		setLuceeConfigServerDir( configServerDir );
		setLuceeConfigWebDir( configWebDir );
		File configCLIServerDir = new File( libDir.getParentFile(),
				"engine/cfml/cli/" );
		File configCLIWebDir = new File( libDir.getParentFile(),
				"engine/cfml/cli/cfml-web" );
		setLuceeCLIConfigServerDir( configCLIServerDir );
		setLuceeCLIConfigWebDir( configCLIWebDir );
		props.setProperty( "cfml.cli.home", cli_home.getAbsolutePath() );
		props.setProperty( "cfml.cli.pwd", getCurrentDir() );
		props.setProperty( "cfml.config.server",
				configServerDir.getAbsolutePath() );
		props.setProperty( "cfml.config.web", configWebDir.getAbsolutePath() );
		props.setProperty( "cfml.server.trayicon", libDir.getAbsolutePath()
				+ "/trayicon.png" );
		props.setProperty( "cfml.server.dockicon", "" );
		for( Object name2 : props.keySet()) {
			String key = ( String ) name2;
			String value = props.get( key ).toString();
			System.setProperty( key, value );
			log.debug( key + ": " + value );
		}
		// Thread shutdownHook = new Thread( "cli-shutdown-hook" ) { public void
		// run() { cl.close(); } };
		// Runtime.getRuntime().addShutdownHook( shutdownHook );

		if( !startServer && !stopServer ) {
			execute( cliArguments );
			System.exit( exitCode );
		} else {
			startRunwarServer( arguments, config );
		}
	}

	private static String mapGetNoCase( Map< String, String > source,
			String text ){
		for( String str : source.keySet()) {
			// check for "--" too
			if( str.toLowerCase().startsWith( text.toLowerCase() )
					|| str.toLowerCase().startsWith( '-' + text.toLowerCase() ) ) {
				return source.get( str );
			}
		}
		return null;
	}

	private static String mapGetNoCase( Properties source, String text ){
		for( Object name2 : source.keySet()) {
			String str = ( String ) name2;
			// check for "--" too
			if( str.toLowerCase().startsWith( text.toLowerCase() )
					|| str.toLowerCase().startsWith( '-' + text.toLowerCase() ) ) {
				return ( String ) source.get( str );
			}
		}
		return null;
	}

	private static Properties mergeProperties( Properties source,
			Properties override ){
		Properties merged = new Properties();
		merged.putAll( source );
		merged.putAll( override );
		return merged;
	}

	private static String removeBinBash( String uri ) throws IOException{
		FileReader namereader = new FileReader( new File( uri ) );
		BufferedReader in = new BufferedReader( namereader );
		String line = in.readLine();
		if( line != null && line.startsWith( "#!" ) ) {
			File tmpfile = new File( uri + ".tmp" );
			tmpfile.deleteOnExit();
			PrintWriter writer = new PrintWriter( tmpfile );
			while( ( line = in.readLine() ) != null ) {
				// writer.println(line.replaceAll(oldstring,newstring));
				writer.println( line );
			}
			uri += ".tmp";
			writer.close();
		}
		in.close();
		return uri;
	}

	public static String[] removeElement( String[] input, String deleteMe ){
		final List< String > list = new ArrayList< String >();
		Collections.addAll( list, input );
		for( String item : input) {
			if( item.toLowerCase().startsWith( deleteMe.toLowerCase() ) ) {
				list.remove( item );
			}
		}
		input = list.toArray( new String[ list.size() ] );
		return input;
	}

	public static String[] removeElementThenAdd( String[] input,
			String deleteMe, String[] addList ){
		List< String > result = new LinkedList< String >();
		for( int x = 0; x < input.length; x++) {
			if( input[ x ].startsWith( deleteMe ) ) {
				x++;
			} else {
				result.add( input[ x ] );
			}
		}

		if( addList != null && addList.length > 0 ) {
			for( String item : addList) {
				result.add( item );
			}
		}

		return result.toArray( input );
	}

	private static void setBackground( Boolean value ){
		isBackground = value;
	}

	private static void setCLI_HOME( File value ){
		CLI_HOME = value;
	}

	private static void setLibDir( File value ){
		libDirectory = value;
	}

	private static void setLuceeCLIConfigServerDir( File value ){
		luceeCLIConfigServerDirectory = value;
	}

	private static void setLuceeCLIConfigWebDir( File value ){
		luceeCLIConfigWebDirectory = value;
	}

	private static void setLuceeConfigServerDir( File value ){
		luceeConfigServerDirectory = value;
	}

	private static void setLuceeConfigWebDir( File value ){
		luceeConfigWebDirectory = value;
	}

	private static void setName( String value ){
		name = value;
	}

	private static void setServerName( String value ){
		serverName = value;
	}

	private static void setShellPath( String value ){
		shellPath = value;
	}

	private static void setWebRoot( File value ){
		webRoot = value;
	}

	private static void startRunwarServer( String[] args,
			Map< String, String > config ) throws ClassNotFoundException,
			NoSuchMethodException, SecurityException, IOException{
		System.setProperty( "apple.awt.UIElement", "false" );
		log.debug( "Running in server mode" );
		// only used for server mode, cli root is /
		File webRoot = getWebRoot();
		String path = LoaderCLIMain.class.getProtectionDomain().getCodeSource()
				.getLocation().getPath();
		// System.out.println("yum from:"+path);
		String decodedPath = java.net.URLDecoder.decode( path, "UTF-8" );
		decodedPath = new File( decodedPath ).getPath();

		// args =
		// removeElementThenAdd(args,"-server","-war "+webRoot.getPath()+" --background false --logdir "
		// + libDir.getParent());
		String name = getName();
		File libDir = getLibDir(), configServerDir = getLuceeConfigServerDir(), configWebDir = getLuceeConfigWebDir();
		String[] addArgs;
		if( isBackground() ) {
			addArgs = new String[] { "-war", webRoot.getPath(),
					"--server-name", getServerName(), "--cfengine-name",
					"lucee", "--cfml-server-config",
					configServerDir.getAbsolutePath(), "--cfml-web-config",
					configWebDir.getAbsolutePath(), "--background", "true",
					"--tray-icon", libDir.getAbsolutePath() + "/trayicon.png",
					"--tray-config",
					libDir.getAbsolutePath() + "/traymenu.json", "--lib-dirs",
					libDir.getPath(), "--debug", Boolean.toString( debug ),
					"--processname", name };
		} else {
			addArgs = new String[] { "-war", webRoot.getPath(),
					"--server-name", getServerName(), "--cfengine-name",
					"lucee", "--cfml-server-config",
					configServerDir.getAbsolutePath(), "--cfml-web-config",
					configWebDir.getAbsolutePath(), "--tray-icon",
					libDir.getAbsolutePath() + "/trayicon.png",
					"--tray-config",
					libDir.getAbsolutePath() + "/traymenu.json", "--lib-dirs",
					libDir.getPath(), "--background", "false", "--debug",
					Boolean.toString( debug ), "--processname", name };
		}
		args = removeElementThenAdd( args, "-server", addArgs );
		if( debug ) {
					System.out.println( "Server args: " + arrayToList( args, " " ) );
				}
		// URLClassLoader rrcl = new
		// URLClassLoader(runwarURL,ClassLoader.getSystemClassLoader());
		// URLClassLoader empty = new URLClassLoader(new URL[0],null);
		// XercesFriendlyURLClassLoader cl = new
		// XercesFriendlyURLClassLoader(urls,null);
		// Thread.currentThread().setContextClassLoader(cl);
		URL[] urls = new URL[ 1 ];
		urls[ 0 ] = libDir.listFiles( new PrefixFilter( "runwar" ) )[ 0 ]
				.toURI().toURL();
		URLClassLoader cl = new URLClassLoader( urls, getClassLoader() );
		Class< ? > runwar;
		try {
			runwar = cl.loadClass( "runwar.Server" );
			Method startServer = runwar.getMethod( "startServer", new Class[] {
					String[].class, URLClassLoader.class } );
			// Thread.currentThread().setContextClassLoader(cl);
			startServer.invoke( runwar.getConstructor().newInstance(),
					new Object[] { args, cl } );
			// startServer.invoke(runwar.getConstructor().newInstance(), new
			// Object[]{args,null});
		} catch ( Exception e ) {
			exitCode = 1;
			if( e.getCause() != null ) {
				e.getCause().printStackTrace();
			} else {
				e.printStackTrace();
			}
		}
		cl.close();
	}

	private static Map< String, String > toMap( String[] args ){
		int index;
		Map< String, String > config = new HashMap< String, String >();
		String raw, key, value;
		if( args != null ) {
			for( String arg : args) {
				raw = arg.trim();
				if( raw.length() == 0 ) {
					continue;
				}
				if( raw.startsWith( "-" ) ) {
					raw = raw.substring( 1 ).trim();
				}
				index = raw.indexOf( '=' );
				if( index == -1 ) {
					key = raw;
					value = "";
				} else {
					key = raw.substring( 0, index ).trim();
					value = raw.substring( index + 1 ).trim();
				}
				config.put( key.toLowerCase(), value );
			}
		}
		return config;
	}

	static Boolean versionFileMatches( File versionFile, String resourcePath )
			throws IOException{
		if( versionFile.exists() ) {
			try {
				String installedVersion = Util.readFile( versionFile.getPath() )
						.trim();
				String currentVersion = Util.getResourceAsString( resourcePath )
						.trim();
				VersionComparator versionComparator = new VersionComparator();
				if( versionComparator
						.compare( currentVersion, installedVersion ) > 0 ) {
					log.warn( "Current version higher than installed version! /n  *current: "
							+ currentVersion
							+ "\n installed: "
							+ installedVersion );
					log.debug( "Current version higher than installed version: "
							+ versionFile.getAbsolutePath()
							+ "/"
							+ resourcePath
							+ ":"
							+ installedVersion
							+ " < "
							+ currentVersion );
					return false;
				}
			} catch ( Exception e ) {
				log.warn( "could not determine version: " + e.getMessage() );
				return false;
			}
		} else {
			log.debug( "update set to true -- no version.properties: "
					+ versionFile.getAbsolutePath() );
			return false;
		}
		return true;
	}

}
