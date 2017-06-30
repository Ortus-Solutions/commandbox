/**
 * - Usage
 * .
 * Adds a single newline to the end of each file in a list of files
 * .
 * {code:bash}
 * utils add-eol-at-eof globber-filter
 * {code}
 * .
 * - Configuration
 * .
 * Set excluded extensions (comma seperated list, no periods)
 * {code:bash}
 * config set utils.eol.excludeExtensions="gitignore,cfml"
 * {code}
 * .
 * Set excluded folders (comma seperated list)
 * {code:bash}
 * config set utils.eol.excludeFolders="node_modules,bower_components"
 * {code}
**/
component aliases="eol" {

	public function run( required Globber files ){
		variables.settings = configService.getconfigSettings();
		variables.excludeFolders = getExcludeFolders();
		variables.excludeExtensions = getExcludeExtensions();

		// filter files
		arguments.files = filterFiles( arguments.files );
		var count = arguments.files.len();

		if ( shell.confirm( "Confirm adding EOL at EOF for #count# #count != 1 ? "files" : "file"#" ) ){
			for ( var file in arguments.files ){
				addEOL( file );
			}
		}
	}

	private function addEOL( filePath ){
		print.line( "Adding EOL at EOF to " & arguments.filePath & "..." );

		// trim  and get line endings
		var content = rTrim( fileRead( arguments.filePath ) );

		// Add single newline to file content
		content &= getLineEndings( content );

		// write new file
		fileWrite( arguments.filePath, content );
	}

	private function getLineEndings( data ){
		if ( arguments.data.len() > 0 ){
			if ( arguments.data[ 1 ].find( chr( 13 ) & chr( 10 ) ) != 0 ){
				return chr( 13 ) & chr( 10 );
			} else if ( arguments.data[ 1 ].find( chr( 13 ) ) != 0 ){
				return chr( 13 );
			}
		}

		return chr( 10 );
	}

	private function isExcludedDirectory( file ){
		// convert all backslashes to forward-slashes
		var f = arguments.file.replace( "\", "/" );

		for ( var i in variables.excludeFolders ){
			// check if file exists in the exclude directory
			if ( f.find( "/" & i & "/" ) || f.startsWith( i )){
				return true;
			}
		}

		// file isn't in any of the exclude directories
		return false;
	}

	private function filterFiles( files ){
		var filteredFiles = [];

		arguments.files.apply( function( file ) {
			var fileInfo = getFileInfo( file );
			// only process files
			if ( fileInfo.type == "file" && !isExcludedDirectory( file ) && !isExcludedFile( file ) ){
				filteredFiles.append( file );
			}
		} );

		return filteredFiles;
	}

	private function isExcludedFile( file ){
		return variables.excludeExtensions.listFind( lCase( listLast( arguments.file, "." ) ) ) != 0;
	}

	private function getExcludeFolders(){
		var folders = ".git";

		try {
			var settingFolders = variables.settings.utils.eol.excludeFolders;
			folders &= ( settingFolders != "" ? "," : "" ) & settingFolders;
		} catch ( any ){}

		return folders;
	}

	private function getExcludeExtensions(){
		var extensions = "3ds,3g2,3gp,7z,a,aac,adp,ai,aif,aiff,alz,ape,apk,ar,arj,asf,au,avi,bak,bh," &
			"bin,bk,bmp,btif,bz2,bzip2,cab,caf,cgm,class,cmx,cpio,cr2,csv,cur,dat,deb,dex,djvu,dll," &
			"dmg,dng,doc,docm,docx,dot,dotm,dra,DS_Store,dsk,dts,dtshd,dvb,dwg,dxf,ecelp4800,ecelp7470," &
			"ecelp9600,egg,eol,eot,epub,exe,f4v,fbs,fh,fla,flac,fli,flv,fpx,fst,fvt,g3,gif,graffle," &
			"gz,gzip,h261,h263,h264,ico,ief,img,ipa,iso,jar,jpeg,jpg,jpgv,jpm,jxr,key,ktx,lha,lvp,lz," &
			"lzh,lzma,lzo,m3u,m4a,m4v,mar,mdi,mht,mid,midi,mj2,mka,mkv,mmr,mng,mobi,mov,movie,mp3,mp4," &
			"mp4a,mpeg,mpg,mpga,mxu,nef,npx,numbers,o,oga,ogg,ogv,otf,pages,pbm,pcx,pdf,pea,pgm,pic," &
			"png,pnm,pot,potm,potx,ppa,ppam,ppm,pps,ppsm,ppsx,ppt,pptm,pptx,psd,pya,pyc,pyo,pyv,qt," &
			"rar,ras,raw,rgb,rip,rlc,rmf,rmvb,rtf,rz,s3m,s7z,scpt,sgi,shar,sil,sketch,slk,smv,so,sub," &
			"swf,tar,tbz,tbz2,tga,tgz,thmx,tif,tiff,tlz,ttc,ttf,txz,udf,uvh,uvi,uvm,uvp,uvs,uvu,viv," &
			"vob,war,wav,wax,wbmp,wdp,weba,webm,webp,whl,wim,wm,wma,wmv,wmx,woff,woff2,wvx,xbm,xif," &
			"xla,xlam,xls,xlsb,xlsm,xlsx,xlt,xltm,xltx,xm,xmind,xpi,xpm,xwd,xz,z,zip,zipx";

		try {
			var settingExtensions = variables.settings.utils.eol.excludeExtensions;
			extensions &= ( settingExtensions != "" ? "," : "" ) & settingExtensions;
		} catch ( any ){}

		return extensions;
	}
}
