package es.xperiments.media
{
	import flash.display.Stage;
	import flash.events.Event;

	import flash.events.EventDispatcher;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.system.Capabilities;

	/**
	 * @author xperiments
	 */
	public class StageWebViewDisk
	{
		public static const isIPHONE : Boolean = Capabilities.os.indexOf( 'iPhone' ) != -1 ? true : false;
		public static const isANDROID : Boolean = Capabilities.version.indexOf( 'AND' ) != -1 ? true : false;
		public static const isMOBILE : Boolean = ( isIPHONE || isANDROID );
		public static const isLINUX : Boolean = Capabilities.version.indexOf( 'LNX' ) != -1 ? true : false;
		public static const isMAC : Boolean = Capabilities.version.indexOf( 'MAC' ) != -1 ? true : false;
		public static const isWINDOWS : Boolean = Capabilities.version.indexOf( 'WIN' ) != -1 ? true : false;
		public static const isDESKTOP : Boolean = ( isLINUX || isMAC || isWINDOWS );

		private static var _applicationCacheDirectory : String;
		private static var _applicationRootPath : String;
		private static var _debugMode : Boolean = false;
		private static var appCacheFile : File ;
		private static var _cached_extensions : Array = [ "html", "htm", "css", "js" ];
		private static var _document_root : String = "www";
		private static var _document_source : String = _document_root + "Source";
		private static var _firstRun : Boolean = true;
		private static var _tmpFile : File = new File();
		private static var _fileStream : FileStream = new FileStream();
		private static var _copyFromFile : File = new File();
		private static var _copyToFile : File = new File();
		private static var _tempFileCounter : uint = 0;
		private static var disp : EventDispatcher;
		
		// This is the javascript code that do the javascript bridge part
		private static const JSXML : XML = <script>
				<![CDATA[
				(function(window)
				{
					window.StageWebViewBridge = (function()
					{         
						var callBacks = [];
						var rootPath = "";
						
						var doCall = function( jsonArgs )
						{
							setTimeout(function() { deferredDoCall(jsonArgs) },0 );
						};
					    
						var deferredDoCall = function( jsonArgs )
						{
							var _serializeObject = JSON.parse( atob( jsonArgs ) );
							var method = _serializeObject.method;
							var returnValue = true;
							if( method.indexOf('[SWVMethod]')==-1 )
							{			
								var targetFunction;
								if( method.indexOf('.')==-1)
								{
									targetFunction = window[ method ];
								}
								else
								{
									var splitedPath = method.split('.');
									targetFunction=window;
									for( var i=0; i<splitedPath.length; i++ )
									{
										targetFunction = targetFunction[ splitedPath[ i ] ];
									};
								};
								returnValue = targetFunction.apply(null, _serializeObject.arguments );
							}
							else
							{
								var targetFunction = callBacks[ method ];
								returnValue = targetFunction.apply(null, _serializeObject.arguments );
							};
				
							if( _serializeObject.callBack !=undefined  )
							{	
								call( _serializeObject.callBack, null, returnValue );  		
							};							
						}; 
						var call = function( )
						{
							var argumentsArray = [];
							var _serializeObject = {};
								_serializeObject.method = arguments[ 0 ];
							if( arguments[ 1 ] !=null ) _serializeObject.callBack = '[SWVMethod]'+arguments[ 0 ];
				
							if( arguments.length>2)
							{
								for (var i = 2; i < arguments.length; i++)
								{
									argumentsArray.push( arguments[ i ] );
								};
							};
				
							_serializeObject.arguments = argumentsArray;
							if( _serializeObject.callBack !=undefined ) { addCallback('[SWVMethod]'+arguments[ 0 ], arguments[ 1 ] ); };
							window.location.href='about:[SWVData]'+btoa( JSON.stringify( _serializeObject ) );
						};
						var addCallback = function( name, fn )
						{
							callBacks[ name ] = fn;
						};	
						var getFilePath = function( fileName )
						{
							return rootPath+'/'+fileName.split('jsfile:/')[1];
						};
						var setRootPath = function( path )
						{
							rootPath = path;	
						};
						window.onload = function()
						{
							call( "getRootPath" , setRootPath );
						};
						return {
							doCall: doCall,
				            call: call,
							getFilePath:getFilePath
						};
					})();
				})(window);
				
				
				]]>
			</script>;

		public static var JSCODE : String  =
			JSXML.toString()
			.replace( new RegExp( "\\n", "g" ), "" )
		.replace( new RegExp( "\\t", "g" ), "" );
		private static var _stage : Stage;


		/**
		 * Main init function
		 * 
		 * @param stage instance
		 * 
		 * @example
		 *	<br>
		 *	// Initialize your debug mode BEFORE!!!<br> 
		 *	StageWebViewDisk.debugMode = true;<br><br> 
		 *	// Initialize your aditionl extensions to preparse BEFORE!!!<br> 
		 *	StageWebViewDisk.setSourceFileExtensions([ "html", "htm", "css", "js", "xml" ]);<br><br> 
		 *	// Call init function<br>
		 *	StageWebViewDisk.initialize( stage )<br>
		 * 
		 */
		public static function initialize( stage:Stage ) : void
		{
			_stage = stage;
			setExtensionsToProcess( _cached_extensions );
			switch( true )
			{
				// ANDROID
				case isANDROID:
					appCacheFile = File.applicationStorageDirectory;
					_applicationCacheDirectory = new File( appCacheFile.nativePath ).url;
					
					break;
				// IOS
				case isIPHONE :
					appCacheFile = new File( new File( "app:/" ).nativePath );
					_applicationCacheDirectory = appCacheFile.url;
					break;
				// DESKTOP OSX
				case isDESKTOP:
					appCacheFile = new File( new File( "app:/" ).nativePath );
					_applicationCacheDirectory = appCacheFile.url;
					break;
			}
			
			_applicationRootPath = _applicationCacheDirectory + '/' + getWorkingDir(); 

			// Determine if is ther first time that the application runs
			_firstRun = new File( _applicationCacheDirectory ).resolvePath( '.swvbinit' ).exists ? false : true;

			// If first run or in DebugMode run the "diskCaching"
			if ( _firstRun || _debugMode )
			{
				processCache();
			}

			// delete our temp directory at start
			deleteTempFolder();
		}

		/**
		 * Enables / Disables DEBUG MODE
		 */
		public static function setDebugMode( mode : Boolean = true ) : void
		{
			_debugMode = mode;
		}

		/**
		 * Sets the file extensions that must be preparsed into cache 
		 * @param extensions Array of extensions ex.:["html","htm","css","js"]
		 * 
		 */
		public static function setExtensionsToProcess( extensions : Array ) : void
		{
			_cached_extensions = extensions;
		}

		/**
		 * Creates and parses a temporally file with the provided contents.
		 * @param contents Contents of the file.
		 * @param extension Extension of the file ( default = "html" ).
		 */
		internal static function createTempFile( contents : String, extension : String = "html" ) : File
		{
			contents = contents.replace( new RegExp( 'appfile:', 'g' ), _applicationRootPath );
			contents = contents.replace( new RegExp( '<head>', 'g' ), '<head><script type="text/javascript">' + JSCODE + '</script>' );
			_fileStream = new FileStream();
			_tmpFile = appCacheFile.resolvePath( 'SWVBTmp/' + ( _tempFileCounter++) + '.' + extension );
			_fileStream.open( _tmpFile, FileMode.WRITE );
			_fileStream.writeUTFBytes( contents );
			_fileStream.close();
			return _tmpFile;
		}

		/**
		 * Creates and parses a new file with the provided contents.
		 * @param fileName the full filename in this format: "appfile:/exampledir/examplefile.html"
		 * @param contents Contents of the file.
		 * @param isHtml Boolean indicatin if file is an htmlFile ( used to inject js code in the html files );
		 */
		public static function createFile( fileName : String, contents : String, isHtml : Boolean = true ) : File
		{
			contents = contents.replace( new RegExp( 'appfile:', 'g' ), _applicationRootPath );
			if ( isHtml ) contents = contents.replace( new RegExp( '<head>', 'g' ), '<head><script type="text/javascript">' + JSCODE + '</script>' );
			_fileStream = new FileStream();
			_tmpFile = appCacheFile.resolvePath( getWorkingDir() + fileName.split( 'appfile:' )[1] );
			_fileStream.open( _tmpFile, FileMode.WRITE );
			_fileStream.writeUTFBytes( contents );
			_fileStream.close();
			return _tmpFile;
		}

		/**
		 * Returns the native path for the fileName
		 * @param fileName Name of the file
		 */
		public static function getFilePath( fileName : String ) : String
		{
			return StageWebViewDisk.appCacheFile.resolvePath( getWorkingDir() + '/' + fileName ).nativePath;
		}

		/**
		 * Returns the path to the www root filesystem
		 */
		public static function getRootPath( ) : String
		{
			return _applicationRootPath;
		}

		/* STATIC EVENT DISPATCHER */
		public static function addEventListener( p_type : String, p_listener : Function, p_useCapture : Boolean = false, p_priority : int = 0, p_useWeakReference : Boolean = false ) : void
		{
			if (disp == null)
			{
				disp = new EventDispatcher();
			}
			disp.addEventListener( p_type, p_listener, p_useCapture, p_priority, p_useWeakReference );
		}

		public static function removeEventListener( p_type : String, p_listener : Function, p_useCapture : Boolean = false ) : void
		{
			if (disp == null)
			{
				return;
			}
			disp.removeEventListener( p_type, p_listener, p_useCapture );
		}

		public static function dispatchEvent( p_event : Event ) : void
		{
			if (disp == null)
			{
				return;
			}
			disp.dispatchEvent( p_event );
		}



		private static function getWorkingDir() : String
		{
			switch( true )
			{
				case isDESKTOP:
					return _debugMode ? _document_source : _document_root;
					break;
				case isIPHONE:
					return _document_root;
					break;
				case isANDROID:
					return _document_source;
					break;
			}
			return "";
		}

		/**
		 * Deletetes the Temp Directory
		 */
		private static function deleteTempFolder() : void
		{
			var tmpFile : File = appCacheFile.resolvePath( 'SWVBTmp' );
			if ( tmpFile.exists )
			{
				tmpFile.deleteDirectory( true );
			}
		}

		/** 
		 * Parses the original files.
		 * This function executes once at app instalation or in DebugMode.
		 */
		private static function processCache() : void
		{
			dispatchEvent( new StageWebviewDiskEvent( StageWebviewDiskEvent.START_DISK_PARSING ) );
			var fileList : Vector.<File> = new Vector.<File>();
			var ext : String;

			getFilesRecursive( fileList, 'app:/' + _document_root );

			for (var e : uint = 0, totalfiles : uint = fileList.length; e < totalfiles; e++)
			{
				ext = fileList[e].extension;
				if ( _cached_extensions.indexOf( fileList[e].extension ) != -1 )
				{
					preparseFile( fileList[e] );
				}
				else
				{
					switch( true )
					{
						case isDESKTOP:
							if ( _debugMode ) fileList[e].copyTo( appCacheFile.resolvePath( _document_source + '/' + fileList[e].name ), true );
							break;
						case isANDROID:
							fileList[e].copyTo( appCacheFile.resolvePath( _document_source + '/' + fileList[e].name ), true );
							break;
					}
				}
			}
			var firstRunFile : File = new File( _applicationCacheDirectory ).resolvePath( '.swvbinit' );
			_fileStream.open( firstRunFile, FileMode.WRITE );
			_fileStream.writeUTF( "init" );
			_fileStream.close();
			firstRunFile = null;
			_firstRun = false;
			dispatchEvent( new StageWebviewDiskEvent( StageWebviewDiskEvent.END_DISK_PARSING ) );
		}

		/**
		 * Parses a file contents.
		 * Injects the JS code into the local files.
		 * Replaces the appfile:/ protocol width the real path on disc
		 * 
		 * @param file File to parse
		 * @pa
		 */
		private static function preparseFile( file : File ) : void
		{
			_copyFromFile.url = file.url;
			_copyToFile.nativePath = appCacheFile.resolvePath( getWorkingDir() + '/' + file.url.split( 'app:/' + _document_root + '/' )[1] ).nativePath;

			// get original file contents
			_fileStream = new FileStream();
			_fileStream.open( _copyFromFile, FileMode.READ );
			var originalFileContents : String = _fileStream.readUTFBytes( _fileStream.bytesAvailable );
			_fileStream.close();

			// parse file contents to change path values
			var fileContents : String = originalFileContents.split( 'appfile:' ).join( _applicationRootPath );
			fileContents = fileContents.split( '<head>' ).join( '<head><script type="text/javascript">' + JSCODE + '</script>' );

			// write file to the cache dir
			_fileStream.open( _copyToFile, FileMode.WRITE );
			_fileStream.writeUTFBytes( fileContents );
			_fileStream.close();
		}

		/**
		 * Recursively get a directory structure 
		 * @param fileList Destination vector file
		 * @param path Current path to process
		 * 
		 */
		private static function getFilesRecursive( fileList : Vector.<File>, path : String = "" ) : void
		{
			var currentFolder : File = new File( path );
			var files : Array = currentFolder.getDirectoryListing();
			for (var f : uint = 0; f < files.length; f++)
			{
				var currFile : File = files[f];
				if (currFile.isDirectory)
				{
					if (currFile.name != "." && currFile.name != "..")
					{
						// add directory
						getFilesRecursive( fileList, currFile.url );
					}
				}
				else
				{
					// if file is not hidden add it
					if ( !currFile.isHidden ) fileList.push( currFile );
				}
			}
		}

		static public function get stage() : Stage
		{
			return _stage;
		}
	}
}
