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
import java.util.Optional;
import java.util.Properties;
import javax.script.ScriptEngineManager;
import javax.script.ScriptEngine;
import java.time.Instant;
import java.nio.file.Paths;
import java.security.Security;
import java.lang.reflect.Field;
import java.lang.reflect.Method;

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
		private static volatile PrintStream printStream;
		
		public static void printstream( PrintStream stream ){
			printStream = stream;
		}
		public static PrintStream printstream(){
			return printStream != null ? printStream : System.out;
		}
		
		public static void debug( String message ){
			if( debug ) {
				printstream().println( message.replace( "/n", CR ) );
			}
		}

		public static void error( String message ){
			printstream().println( message.replace( "/n", CR ) );
		}

		public static void warn( String message ){
			printstream().println( message.replace( "/n", CR ) );
		}

		public static void info( String message ){
			printstream().println( message.replace( "/n", CR ) );
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

	public static Object			FRTrans;
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
	private static Boolean			initialized				= false;
	private static String			ENGINECONF_ZIP_PATH		= "engine.zip";
	private static int				exitCode				= 0;
	private static String			LIB_ZIP_PATH			= "libs.zip";
	private static File				libDirectory;
	private static File				luceeCLIConfigServerDirectory, luceeCLIConfigWebDirectory;
	private static String			name;

	private static String			shellPath;

	private static String			VERSION_PROPERTIES_PATH	= "cliloader/version.properties";

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

	public static void execute( ArrayList< String > cliArguments )
			throws ClassNotFoundException, NoSuchMethodException,
			SecurityException, IOException{
		log.debug( "Running in CLI mode" );

		System.setIn( new NonClosingInputStream( System.in ) );

		InputStream originalIn = System.in;
		PrintStream originalOut = System.out;

		execute(cliArguments,System.in,System.out);

		System.setOut( originalOut );
		System.setIn( originalIn );
	}

	public static void execute( ArrayList< String > cliArguments, InputStream inputStream, PrintStream printStream )
			throws ClassNotFoundException, NoSuchMethodException,
			SecurityException, IOException {
		log.printstream(printStream);
		log.debug( "Running in CLI mode" );
		if(!initialized) {
			try {
				initialize(cliArguments.toArray(new String[cliArguments.size()]));
			} catch (Exception e){
				System.err.println("*******  ERROR initializing ***********");
				e.printStackTrace();
			}
		}
		removeInternalArguments(cliArguments);
		String uri = null;
		File home = getCLI_HOME();
		if(home == null){
			String[] arguments = cliArguments.toArray(new String[cliArguments.size()]);
			Map< String, String > config = toMap( arguments );
			home = getCLI_HOME(cliArguments,System.getProperties(),arguments,config);
		}
		String shellPath = getShellPath();
		if( new File( home, shellPath ).exists() ) {
			uri = new File( getCLI_HOME(), getShellPath() ).getCanonicalPath();
		} else if( new File( getShellPath() ).exists() ) {
			uri = new File( getShellPath() ).getCanonicalPath();
		} else {
			log.error( "Could not find shell:" + getShellPath() );
			exitCode = 1;
			return;
		}
		// Check for "box foo.cfm" or "box foo.cfm param1 ..."
		// This is mostly just for backwards compat and to enforce consistency.
		if( cliArguments.size() > 0  
				&& new File( cliArguments.get( 0 ) ).exists()
				&& new File( cliArguments.get( 0 ) ).isFile()
				&& ( cliArguments.get( 0 ).toLowerCase().endsWith( ".cfm" )
					|| isShebang( new File( cliArguments.get( 0 ) ).getCanonicalPath() ) ) ) {
			
			log.debug( "Funneling: " + cliArguments.get( 0 ) + " through execute command." );
			
			String CFMLFile = new File( cliArguments.get( 0 ) ).getCanonicalPath();
			
			// handle bash script
			String CFMLFile2 = removeBinBash( CFMLFile );
			if( !CFMLFile.equals( CFMLFile2 ) ) {
				cliArguments.set( 0, CFMLFile2 );
			} 
			
			// Funnel through the exec command.
			cliArguments.add( 0, "exec" );
			log.debug( "Executing: " + uri );
			
		} else if( cliArguments.size() > 0
				&& new File( cliArguments.get( 0 ) ).isFile() ) {
			
			String filename = cliArguments.get( 0 ).toLowerCase();
			// This will force the shell to run the recipe command
			if( filename.endsWith( ".rs" ) || filename.endsWith( ".boxr" ) ) {
				log.debug( "Executing batch file: " + filename );
				cliArguments.add( 0, "recipe" );
			}
		} else {
			if( debug ) {
				printStream.println( "uri: " + uri );
			}
		}
		
		try { 
			Class FRAPIClass = classLoader.loadClass( "com.intergral.fusionreactor.api.FRAPI" );
		    Method getInstance = FRAPIClass.getMethod("getInstance", (Class[])null);

			while( getInstance.invoke( FRAPIClass, (Object[])null ) == null ) {
				if( debug ) {
					printStream.println( "Waiting on FusionReactor to load..." );
				}
				Thread.sleep( 500 );
			}
			Object FRAPIInstance = getInstance.invoke( FRAPIClass, (Object[])null );
		    Method isInitialized = FRAPIInstance.getClass().getMethod("isInitialized", (Class[])null);			
			while( !(Boolean)isInitialized.invoke( FRAPIInstance, (Object[])null ) ) {
				if( debug ) {
					printStream.println( "Waiting on FusionReactor to load..." );
				}
				Thread.sleep( 500 );
			}
			
		    Method createTrackedTransaction = FRAPIInstance.getClass().getMethod("createTrackedTransaction", String.class );		

		    FRTrans = createTrackedTransaction.invoke( FRAPIInstance, "CLI Java Startup" );

		    Method setTransactionApplicationName = FRAPIClass.getMethod("setTransactionApplicationName", String.class );
		    setTransactionApplicationName.invoke( FRAPIInstance, "CommandBox CLI" );

		    Method setDescription = FRTrans.getClass().getMethod("setDescription", String.class );
		    setDescription.invoke( FRTrans, "Java Code from start of JVM to CF code running" );
		    
		} catch( Throwable e ) {
			if( debug ) {
				printStream.println( e.getMessage() );
				//throw new IOException( e );
			}
			
		}
		
		System.setProperty( "cfml.cli.arguments", arrayToList( cliArguments.toArray( new String[ cliArguments.size() ] ), " " ) );
		System.setProperty( "cfml.cli.argument.list", arrayToList( cliArguments.toArray( new String[ cliArguments.size() ] ), "," ) );
		
		JSONArray jsonArray = new JSONArray();
		jsonArray.addAll( cliArguments );
		System.setProperty( "cfml.cli.argument.array", jsonArray.toJSONString() );
		
		if( debug ) {
			printStream.println( "cfml.cli.arguments: " + Arrays.toString( cliArguments.toArray() ) );
			printStream.println( "cfml.cli.argument.array: " + jsonArray.toJSONString() );
		}

		URLClassLoader cl = getClassLoader();
		
		try {

			// This is a fix for Windows machine to avoid very slow access to the network adapter's mac address during UUID creation in Felix startup:
			// https://www.mail-archive.com/users@felix.apache.org/msg18083.html
			Optional.ofNullable( Security.getProvider( "SunMSCAPI" ) ).ifPresent( p->{
			    Security.removeProvider( p.getName() );
			    Security.insertProviderAt( p, 1 );
			} );
			
			String webroot = Paths.get( uri ).toAbsolutePath().getRoot().toString();
            // On a *nix machine
            if( webroot.equals( "/" ) ) {
            	// Include first folder like /usr/
            	webroot += Paths.get( uri ).toAbsolutePath().subpath( 0, 1 ).toString() + "/";
            }
			
            // Escape backslash in webroot since replace uses a regular expression
			String bootstrap = "/" + Paths.get( uri ).toAbsolutePath().toString().replaceFirst( webroot.replace( "\\", "\\\\" ), "" );

    		System.setProperty( "lucee.web.dir", getLuceeCLIConfigWebDir().getAbsolutePath() );
    		System.setProperty( "lucee.base.dir", getLuceeCLIConfigServerDir().getAbsolutePath() );
    		System.setProperty( "felix.cache.locking", "false" );
    		System.setProperty( "felix.storage.clean", "none" );
    		
    		// Load up JSR-223!
            ScriptEngineManager engineManager = new ScriptEngineManager( cl );
            ScriptEngine engine = engineManager.getEngineByName( "CFML" );
            
			if( debug ) {
				printStream.println( "Webroot: " + webroot );
				printStream.println( "Bootstrap: " + bootstrap );
			}
			
    		String CFML = "loader = createObject( 'java', 'cliloader.LoaderCLIMain' ); \n" 
    				+ "if( !isNull( loader.FRTrans ) ) { loader.FRTrans.close(); } \n" 
    				+ "\n" 
    				+ "mappings = getApplicationSettings().mappings; \n"
    	    		+ " mappings[ '/__commandbox_root/' ] = '" + webroot + "'; \n"
    	            + " application mappings='#mappings#' action='update'; \n"
            		+ " include '/__commandbox_root" + bootstrap.replace( "'", "''" ) + "'; \n";

			if( debug ) {
				printStream.println( "" );
				printStream.println( CFML );
				printStream.println( "" );
			}

			try {
				
	    		// Kick off the box bootstrap
	            engine.eval( CFML );
	            
			} catch( javax.script.ScriptException e ) {
				if( e.getCause() != null && e.getCause().getClass().getName() == "lucee.runtime.exp.Abort"  ) {
					// Just a CFAbort, nothing to do here
				} else {
					throw( e );
				}
			}
            
		} catch ( Exception e ) {
			exitCode = 1;
			e.printStackTrace();
			if( e.getCause() != null ) {
				printStream.println( "Cause:" );
				e.getCause().printStackTrace();
			}
		}
		

		if( debug ) {
			printStream.println( "cfml.cli.exitCode: " + Integer.parseInt( System.getProperty("cfml.cli.exitCode","0") ) );
		}
		exitCode = Integer.parseInt( System.getProperty("cfml.cli.exitCode","0") );
		
		cl.close();
		printStream.flush();
		}

	public static URLClassLoader getClassLoader(){
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
				log.error( "Could not find libraries" );
				System.exit( 1 );
			}

			for( File jar : children) {
				jars.add( jar );
				if( !jar.getName().contains( "runwar" ) ) {
				}
			}
			URL[] urls = new URL[ jars.size() ];
			log.debug( "Loading Jars" );
			for( int i = 0; i < jars.size(); i++) {
				try {
					urls[ i ] = jars.get( i ).toURI().toURL();
					log.debug( "- " + urls[ i ] );
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
					InputStream fi;
					try {
						log.debug( "checking for home in properties from "
								+ cliPropFile.getCanonicalPath() );
						fi = new BOMInputStream( new FileInputStream( cliPropFile ), false );
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

	private static String getName(){
		return name;
	}

	public static String getPathRoot( String string ){
		return string.replaceAll( "^([^\\\\//]*?[\\\\//]).*?$", "$1" );
	}

	private static String getShellPath(){
		return shellPath;
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
		disableAccessWarnings();
		System.setProperty("log4j.configuration", "resource/log4j.xml");
		Util.ensureJavaVersion();
		execute( initialize( arguments ) );
		System.exit( exitCode );
	}

	@SuppressWarnings( "static-access" )
	public static ArrayList< String > initialize( String[] arguments ) throws IOException {
		System.setProperty( "apple.awt.UIElement", "true" );
		ArrayList< String > cliArguments = new ArrayList< String >(
				Arrays.asList( arguments ) );
		File cli_home;
		Boolean updateLibs = false;

		Properties props = new Properties(), userProps = new Properties();
		if( listContains( cliArguments, "-clidebug" ) ) {
			debug = true;
			listRemoveContaining( cliArguments, "-clidebug" );
			arguments = removeElement( arguments, "-clidebug" );
		}

		System.setProperty( "cfml.cli.debug", debug.toString() );
		try {
			props.load( ClassLoader
					.getSystemResourceAsStream( "cliloader/cli.properties" ) );
		} catch ( Exception e ) {
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
			log.debug( "merging properties from " + cliPropFile.getCanonicalPath() );
			InputStream fi = new BOMInputStream( new FileInputStream( cliPropFile ), false );
			userProps.load( fi );
			fi.close();
			props = mergeProperties( props, userProps );
		}

		log.debug( "cfml.cli.name: " + name );
		setShellPath( props.getProperty( "shell" ) != null ? props.getProperty( "shell" ) : "/cfml/cli/shell.cfm" );

		cli_home = getCLI_HOME( cliArguments, props, arguments, config );
		arguments = removeElement( arguments, "-" + getName() + "_home" );

		log.debug( "initial cfml.cli.home: " + cli_home );
		if( !cli_home.exists() ) {
			log.info( "Configuring " + name + " home: " + cli_home + " (change with -" + name + "_home=/path/to/dir)" );
			cli_home.mkdir();
		}

		if( new File( cli_home, "cli.properties" ).isFile() ) {
			InputStream fi = new BOMInputStream( new FileInputStream( new File( cli_home, "cli.properties" ) ), false );
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
		if( listContains( cliArguments, "-cliupdate" ) ) {
			log.info( "updating " + name + " home" );
			updateLibs = true;
			listRemoveContaining( cliArguments, "-cliupdate" );
			arguments = removeElement( arguments, "-cliupdate" );
		}

		setLibDir( new File( cli_home, "lib" ).getCanonicalFile() );

		if( listContains( cliArguments, "-clishellpath" ) ) {
			int shellpathIdx = listIndexOf( cliArguments, "-clishellpath" );
			String shellpath = cliArguments.get( shellpathIdx );
			if( shellpath.indexOf( '=' ) == -1 ) {
				setShellPath( cliArguments.get( shellpathIdx + 1 ) );
				cliArguments.remove( shellpathIdx + 1 );
				cliArguments.remove( shellpathIdx );
			} else {
				setShellPath( shellpath.split( "=" )[ 1 ] );
				cliArguments.remove( shellpathIdx );
			}
			arguments = removeElement( arguments, "-clishellpath" );
		}
		props.setProperty( "cfml.cli.shell", getShellPath() );

		File libDir = getLibDir();
		props.setProperty( "cfml.cli.lib", libDir.getAbsolutePath() );
		File cfmlDir = new File( cli_home.getPath() + "/cfml" );
		File cfmlSystemDir = new File( cli_home.getPath() + "/cfml/system" );
		File cfmlBundlesDir = new File( cli_home.getPath() + "/engine/cfml/cli/lucee-server/bundles" );
		File cfmlFelixCacheDir = new File( cli_home.getPath() + "/engine/cfml/cli/lucee-server/felix-cache" );

		// clean out any leftover pack files (an issue on windows)
		Util.cleanUpUnpacked( libDir );

		if( libDir.exists() ) {
			File versionFile = new File( libDir, "version.properties" );
			if( !versionFileMatches( versionFile, VERSION_PROPERTIES_PATH ) ) {
				String autoUpdate = props.getProperty( "cfml.cli.autoupdate" );
				if( autoUpdate != null && Boolean.parseBoolean( autoUpdate ) ) {
					log.warn( "\n*updating installed jars" );
					updateLibs = true;
					versionFile.delete();
				} else {
					log.warn( "run '" + name + " -update' to install new version" );
				}
			}
		}

		if( !libDir.exists()
				|| libDir.listFiles( new ExtFilter( ".jar" ) ).length < 2
				|| updateLibs ) {
			log.info( "Library path: " + libDir );
			log.info( "Initializing libraries -- this will only happen once, and takes a few seconds..." );
						
			// OSGI can be grumpy on uprade with comppeting bundles.  Start fresh
			if( cfmlBundlesDir.exists() ) {
				log.info( "Cleaning old OSGI Bundles..." );
				Util.deleteDirectory( cfmlBundlesDir );
			}
			// OSGI can be grumpy on uprade with comppeting bundles.  Start fresh
			if( cfmlSystemDir.exists() ) {
				log.info( "Cleaning old Felix Cache..." );
				Util.deleteDirectory( cfmlFelixCacheDir );
			}
			
			// Try to delete the Runwar jar first since it's the most likely to be locked.  
			// If it fails, this method will just abort before we get any farther into deleting stuff.
			Util.checkIfJarsLocked( libDir, "runwar" );
			// Ok, try deleting for real.  If any of these jars fail to delete, we'll still holler at the user and abort the upgrade
			Util.removePreviousLibs( libDir );
			
			Util.unzipInteralZip( classLoader, LIB_ZIP_PATH, libDir, debug );
			
			// Wipe out existing /cfml/system folder to remove any deleted files
			if( cfmlSystemDir.exists() ) {
				Util.deleteDirectory( cfmlSystemDir );
			}
		
			Util.unzipInteralZip( classLoader, CFML_ZIP_PATH, cfmlDir, debug );
			
			Util.unzipInteralZip( classLoader, ENGINECONF_ZIP_PATH, new File(
					cli_home.getPath() + "/engine" ), debug );
			Util.copyInternalFile( classLoader, VERSION_PROPERTIES_PATH,
					new File( libDir, "version.properties" ) );
			log.info( "" );
			log.info( "Libraries initialized" );
			if( updateLibs && arguments.length == 0 ) {
				log.info( "updated " + cli_home + "!" );
				// log.info("updated! ctrl-c now or wait a few seconds for exit..");
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

					// Wipe out existing /cfml/system folder to remove any deleted files
					if( cfmlSystemDir.exists() ) {
						// This also inherently clears the metadata cache since it was inside this folder
						Util.deleteDirectory( cfmlSystemDir );
					}
					
					Util.unzipInteralZip( classLoader, CFML_ZIP_PATH, cfmlDir, debug );
				} else {
					log.warn( "run '" + name + " -update' to install new CFML" );
				}
			}
		}


		// Allow the user to add ad-hoc Java props to the process via an environment variable called
		// BOX_JAVA_PROPS that is a semi-colon delimited list of key=value pairs.
		// BOX_JAVA_PROPS="foo=bar;brad=wood"
		Map< String, String > env = System.getenv();
		if( mapGetNoCase( env, "BOX_JAVA_PROPS" ) != null ) {
			log.debug( "Environment Variable BOX_JAVA_PROPS found." );
			String BOX_JAVA_PROPS = mapGetNoCase( env, "BOX_JAVA_PROPS" );
			if( BOX_JAVA_PROPS.length() > 0 ) {
				log.debug( "Environment Variable BOX_JAVA_PROPS: " + BOX_JAVA_PROPS );
				String[] boxJavaProps = BOX_JAVA_PROPS.split( ";" );

                for( String thisBoxJavaProp : boxJavaProps ) {
                	if( thisBoxJavaProp.indexOf( '=' ) != -1 ) {
           				System.setProperty( thisBoxJavaProp.split( "=" )[ 0 ], thisBoxJavaProp.split( "=" )[ 1 ] );
    					log.debug( "Added BOX_JAVA_PROP to System Properties:" + thisBoxJavaProp );
    				} else {
    					log.debug( "BOX_JAVA_PROP is malformed. Missing equals sign: " + thisBoxJavaProp.split( "=" )[ 0 ] + "=" + thisBoxJavaProp.split( "=" )[ 1 ] );
    				}
                }
			}
		}
		
		File configCLIServerDir = new File( libDir.getParentFile(), "engine/cfml/cli/" );
		File configCLIWebDir = new File( libDir.getParentFile(), "engine/cfml/cli/cfml-web" );
		
		setLuceeCLIConfigServerDir( configCLIServerDir );
		setLuceeCLIConfigWebDir( configCLIWebDir );
		
		props.setProperty( "cfml.cli.home", cli_home.getAbsolutePath() );
		props.setProperty( "cfml.cli.pwd", getCurrentDir() );
		props.setProperty( "cfml.server.dockicon", "" );
		
		for( Object name2 : props.keySet()) {
			String key = ( String ) name2;
			String value = props.get( key ).toString();
			System.setProperty( key, value );
			log.debug( key + ": " + value );
		}

		initialized = true;
		return cliArguments;
	}

	private static void removeInternalArguments(ArrayList< String > cliArguments){
		String name = getName();
		String home = name + "_home";
		listRemoveContaining( cliArguments, "-" + home );
		listRemoveContaining( cliArguments, "-cliupdate" );
		listRemoveContaining( cliArguments, "-clidebug" );
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

	private static Boolean isShebang( String uri ) throws IOException{
		FileReader namereader = new FileReader( new File( uri ) );
		BufferedReader in = new BufferedReader( namereader );
		String line = in.readLine();
		if( line != null && line.startsWith( "#!" ) ) {
			return true;
		}
		return false;
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

	private static void setName( String value ){
		name = value;
	}

	private static void setShellPath( String value ){
		shellPath = value;
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

	@SuppressWarnings("unchecked")
    public static void disableAccessWarnings() {
        try {
            Class unsafeClass = Class.forName("sun.misc.Unsafe");
            Field field = unsafeClass.getDeclaredField("theUnsafe");
            field.setAccessible(true);
            Object unsafe = field.get(null);

            Method putObjectVolatile = unsafeClass.getDeclaredMethod("putObjectVolatile", Object.class, long.class, Object.class);
            Method staticFieldOffset = unsafeClass.getDeclaredMethod("staticFieldOffset", Field.class);

            Class loggerClass = Class.forName("jdk.internal.module.IllegalAccessLogger");
            Field loggerField = loggerClass.getDeclaredField("logger");
            Long offset = (Long) staticFieldOffset.invoke(unsafe, loggerField);
            putObjectVolatile.invoke(unsafe, loggerClass, offset, null);
        } catch (Exception ignored) {
        }
    }
	
}
