/*
Copyright 2011 Pedro Casaubon

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package es.xperiments.media
{
	import flash.display.BitmapData;
	import flash.display.JointStyle;
	import flash.display.Stage;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.FocusEvent;
	import flash.events.LocationChangeEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.geom.Rectangle;
	import flash.media.StageWebView;
	
	public class StageWebViewBridge extends EventDispatcher
	{

		public static var DEBUGMODE:Boolean = true; 
		public var bridge:StageWebViewBridgeExternal;
		
		private static const ROOT_PATH:String = new File(new File( "app:/" ).nativePath).url;
		private static const DEFAULT_CACHED_EXTENSIONS:Array = ["html","htm","css","js"];
		private static var CACHED_EXTENSIONS:Array;
		private static var DOCUMENT_ROOT:String = "html";
		private static var DOCUMENT_CACHE:String = DOCUMENT_ROOT+"Cache";
		private static var DOCUMENT_SOURCE:String = DOCUMENT_ROOT+"Source";
		private static var FIRST_RUN:Boolean = true;
		
		
		private var _view:StageWebView;
		private var _fileStream:FileStream; 
		private var _tmpFile:File = new File();
		private var _copyFromFile:File = new File();
		private var _copyToFile:File = new File();
		
		// JAVASCRIPT CODE
		private static const JSXML:XML =
			<script>
				<![CDATA[
					if( window.StageWebViewBridge == null )
					{
						window.StageWebViewBridge = {};
						window.StageWebViewBridge.callBacks = [];
						window.StageWebViewBridge.doCall = function( jsonArgs )
						{
							var _serializeObject = JSON.parse( atob( jsonArgs ) );
							var method = _serializeObject.method;
							var returnValue = null;
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
								}
								returnValue = targetFunction.apply(null, _serializeObject.arguments );
							}
							else
							{
								var targetFunction = window.StageWebViewBridge.callBacks[ method ];
								returnValue = targetFunction.apply(null, _serializeObject.arguments );
							}
							if( _serializeObject.callBack !=undefined && returnValue!=null )
							{	
								window.StageWebViewBridge.call( _serializeObject.callBack, null, returnValue );  		
							}
	
						};
						window.StageWebViewBridge.call = function( )
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
								}
							}
	
							_serializeObject.arguments = argumentsArray;
							if( _serializeObject.callBack !=undefined ) window.StageWebViewBridge.addCallback('[SWVMethod]'+arguments[ 0 ], arguments[ 1 ] );
							window.location.href='about:[SWVData]'+btoa( JSON.stringify( _serializeObject ) );
						};
			
						window.StageWebViewBridge.addCallback = function( name, fn )
						{
							window.StageWebViewBridge.callBacks[ name ] = fn;
						};	
			
						window.alert = function(native)
						{
							window.nativeAlert = native; 
							return function(str)
							{
								setTimeout('window.nativeAlert("'+str+'");',10);
							};
						}(window.alert);	
					};
				]]>
			</script>;
		private static const JSCODE:String = JSXML.toString().replace( new RegExp( "\\n", "g" ), "" ).replace( new RegExp( "\\t", "g" ), "" );		
		
		// Static Class Initializer
		{
			setSourceFileExtensions( DEFAULT_CACHED_EXTENSIONS );
			FIRST_RUN = File.applicationDirectory.resolvePath('firstRun.flag').exists ? false:true;
		}		
		
		
		public function StageWebViewBridge()
		{
			_view = new StageWebView();
			_fileStream = new FileStream(); 
			if( DEBUGMODE==true || FIRST_RUN ) processCache(); 
			// this made the magic!! 
			 
			bridge = new StageWebViewBridgeExternal( this );             
			_view.addEventListener(Event.COMPLETE,onListener );  
			_view.addEventListener(ErrorEvent.ERROR,onListener );
			_view.addEventListener(FocusEvent.FOCUS_IN,onListener );  
			_view.addEventListener(FocusEvent.FOCUS_OUT,onListener );
			_view.addEventListener(LocationChangeEvent.LOCATION_CHANGE,onListener );
			_view.addEventListener(LocationChangeEvent.LOCATION_CHANGING, onListener );
		}

		/**
		 * Sets the document 
		 * @param htmlRoot
		 * @param htmlCacheRoot
		 * 
		 */		
		public static function setRootFolder( htmlRoot:String="html"):void
		{
			DOCUMENT_ROOT = htmlRoot;
			DOCUMENT_CACHE = DOCUMENT_ROOT+'Cache';
			DOCUMENT_SOURCE = DOCUMENT_ROOT+'Source';
		}	
		
		/**
		 * Sets the file extensions that musy be preparsed into cache 
		 * @param ext Array of extensions ex.:["html","htm","css","js"]
		 * 
		 */		
		public static function setSourceFileExtensions( extensions:Array ):void 
		{
			CACHED_EXTENSIONS = extensions;
		}
		
		/**
		 * Generic StageWebView Listener. Controls LOCATION_CHANGING events for catching special cases.
		 */		
		private function onListener( e:Event ):void
		{
			switch( true )
			{
				case e.type == LocationChangeEvent.LOCATION_CHANGING:
					var currLocation:String = unescape((e as LocationChangeEvent).location);
					
					switch( true )
					{
						
						// special case when javascript calls come from the location
						case currLocation.indexOf('about:[SWVData]')!=-1:
							e.preventDefault();	
							bridge.parseCallBack( currLocation.split('about:[SWVData]')[1] ); 
							break;
						// special case when a internal link come from the page
						case currLocation.indexOf('applink:')!=-1:  
							e.preventDefault();
							loadLocalURL( currLocation ); 
							break;	
						default:
							dispatchEvent( e );
							break;	
						
					} 					
					
				break;
				default:
					dispatchEvent( e );	
				break;	
			}	

		} 
		/**
		 * Processes the cache maintenance.
		 * Update the cached files when the don't exist or has been updated.
		 * Change DEBUGMODE to false for switch between DEBUG or PRODUCTION mode
		 *  
		 */		
		public function processCache():void
		{
			var currentRootPath:String = DEBUGMODE ? DOCUMENT_ROOT:DOCUMENT_SOURCE;
			var fileList:Vector.<File> = new Vector.<File>();
			var cached_extensionsString:String = CACHED_EXTENSIONS.join(',');
			var ext:String;
			createCacheDir();
			getFilesRecursive( fileList,'app:/'+currentRootPath); 

			if( FIRST_RUN )
			{ 
				for(var e:uint = 0; e<fileList.length; e++)
				{
					ext = fileList[e].extension;
					if( cached_extensionsString.indexOf( fileList[e].extension )!=-1 )
					{
						preparseFile( fileList[e] , ( ext == "html" || ext == "htm") );
					}  
				}
				_tmpFile.nativePath = File.applicationDirectory.resolvePath('firstRun.flag').nativePath;
				_fileStream.open(_tmpFile, FileMode.WRITE);
				_fileStream.writeUTFBytes( 'firstRun=true' ); 
				_fileStream.close();
				FIRST_RUN = false;
 			}	   
			   

			for ( var i:uint = 0; i<fileList.length; i++)
			{
				ext = fileList[i].extension;
				if( cached_extensionsString.indexOf( ext )!=-1 )
				{
					preparseFile( fileList[i] , ( ext == "html" || ext == "htm") );
				}
				else
				{
						_copyFromFile.nativePath = fileList[i].nativePath;
						_copyToFile.nativePath = File.applicationDirectory.resolvePath( DOCUMENT_CACHE+'/'+fileList[i].url.split('app:/'+DOCUMENT_ROOT+'/')[1] ).nativePath;
						if( _copyToFile.exists )
						{
							if( _copyFromFile.modificationDate.getTime() > _copyToFile.modificationDate.getTime() )
							{
								_copyFromFile.copyTo(_copyToFile,true );
							}	
						}  
						else
						{
							_copyFromFile.copyTo(_copyToFile,true );						
						}
				} 	
			}

		} 
		
		private function createCacheDir():void
		{
			var cacheDir:String = File.applicationDirectory.resolvePath( DOCUMENT_CACHE ).nativePath;
			_tmpFile.nativePath = cacheDir;
			_tmpFile.createDirectory();			
		} 
		 
		private function preparseFile( file:File, ishtml:Boolean = false ):void
		{ 

			var currentRootPath:String = DEBUGMODE ? DOCUMENT_ROOT:DOCUMENT_SOURCE;
			var update:Boolean = false;
			
			_copyFromFile.nativePath = file.nativePath;
			_copyToFile.nativePath = File.applicationDirectory.resolvePath( DOCUMENT_CACHE+'/'+file.url.split('app:/'+currentRootPath+'/')[1] ).nativePath; 

			if( !_copyToFile.exists )
			{
				update = true;
			}
			else
			{	
				// is file newer?
				if ( _copyFromFile.modificationDate.getTime() > _copyToFile.modificationDate.getTime() || FIRST_RUN )
				{
					update=true;
				}
			} 
			
			// First time we must do the fileupdate to correct plattform paths
			if( FIRST_RUN ) update = true;
			
			if( !update ){ return; }
			
			// get original file contents
			_fileStream.open(_copyFromFile, FileMode.READ);
			var originalFileContents:String = _fileStream.readUTFBytes(_fileStream.bytesAvailable);
			_fileStream.close();
			
			// parse file contents to change path values
			var fileContents:String = originalFileContents.split('appfile:').join( ROOT_PATH+'/'+DOCUMENT_CACHE );
			if( ishtml )   
			{
				fileContents = fileContents.split('<head>').join( '<head><script type="text/javascript">'+JSCODE+'</script>' );
			}	 
			
			// write file to the cache dir 
			_fileStream.open(_copyToFile, FileMode.WRITE );
			_fileStream.writeUTFBytes( fileContents ); 
			_fileStream.close();
			
			// on Debug mode copy the original file to the release source dir
			if( DEBUGMODE )
			{	
				_copyToFile.nativePath = File.applicationDirectory.resolvePath( DOCUMENT_SOURCE+'/'+file.url.split('app:/'+DOCUMENT_ROOT+'/')[1] ).nativePath; 
				_fileStream.open(_copyToFile, FileMode.WRITE );
				_fileStream.writeUTFBytes( originalFileContents ); 
				_fileStream.close();
			}
			
		}
		
		
		
		/**
		 * Recursively get a directory structure 
		 * @param fileList Destination vector file
		 * @param path Current path to process
		 * 
		 */		 
		private function getFilesRecursive( fileList:Vector.<File>, path:String="" ):void
		{
			var currentFolder:File = new File( path );
			var files:Array = currentFolder.getDirectoryListing();
			for (var f:uint = 0; f < files.length; f++)
			{
				if (files[f].isDirectory)
				{
					if (files[f].name !="." && files[f].name !="..")
					{ 
						//dir
						getFilesRecursive(fileList, files[f].url);
					}
				} 
				else 
				{ 
					//file
					fileList.push(files[f]);
				}
			}            
		}	
		
		
		/**
		 * Loads a local htmlFile into the webview.
		 * 
		 * To link files in html use the "applink:/" protocol:
		 * <a href="applink:/index.html">index</a>
		 * 
		 * For images,css,scripts... etc, use the "appfile:/" protocol:
		 * <img src="appfile:/image.png">
		 * 
		 * @param url	The url file with applink:/ protocol
		 * 				
		 * 				Usage: stageWebViewBridge.loadLocalURL('applink:/index.html');
		 */		
		public function loadLocalURL( url:String ):void
		{
			var fileName:String = url.split('applink:/')[1];
			_tmpFile.nativePath = File.applicationDirectory.resolvePath( DOCUMENT_CACHE+'/'+fileName ).nativePath; 
			 
 			_view.loadURL( _tmpFile.url ); 
			
		}			 
		
		 
		
		// GETTERS SETTERS
		
		public function set stage( stg:Stage ):void
		{
			_view.stage = stg;
		}
		public function get stage( ):Stage
		{
			return _view.stage; 
		}	
		public function set viewPort( rectangle:Rectangle ):void
		{
			_view.viewPort = rectangle;
		}
		public function get viewPort( ):Rectangle
		{
			return _view.viewPort;
		}
		public function get isHistoryBackEnabled( ):Boolean
		{
			return _view.isHistoryBackEnabled;
		}		
		public function get isHistoryForwardEnabled( ):Boolean
		{
			return _view.isHistoryForwardEnabled;
		}
		public function get location( ):String
		{
			return _view.location;
		}		
		public function get title( ):String
		{
			return _view.title;
		}		
		
		/// METHODS
		public function assignFocus(direction:String = "none"):void
		{
			_view.assignFocus( direction );
		}	
		public function dispose():void 
		{
			_view.removeEventListener(Event.COMPLETE,onListener );
			_view.removeEventListener(ErrorEvent.ERROR,onListener );
			_view.removeEventListener(FocusEvent.FOCUS_IN,onListener );
			_view.removeEventListener(FocusEvent.FOCUS_OUT,onListener );
			_view.removeEventListener(LocationChangeEvent.LOCATION_CHANGE,onListener );
			_view.removeEventListener(LocationChangeEvent.LOCATION_CHANGING, onListener );			
			_view.dispose();
			bridge = null;
		}
		public function drawViewPortToBitmapData(bitmap:BitmapData):void
		{
			_view.drawViewPortToBitmapData( bitmap );
		}	
		public function historyBack():void
		{
			_view.historyBack( );
		}
		public function historyForward():void
		{
			_view.historyForward( ); 
		}
		
		/**
		 * Enhaced loadString
		 * Loads a string and inject the javascript comunication code into it. 
		 */		
		public function loadString(text:String, mimeType:String = "text/html"):void
		{
			text=text.replace(new RegExp('appfile:','g'), ROOT_PATH );
			text=text.replace(new RegExp('<head>','g'), '<head><script type="text/javascript">'+JSCODE+'</script>' );
			_view.loadString( text, mimeType );
		}
		public function loadURL(url:String):void
		{
			_view.loadURL( url );
		}
		public function reload():void
		{
			_view.reload( );
		}
		public function stop():void
		{
			_view.stop( );
		}	
	}
}