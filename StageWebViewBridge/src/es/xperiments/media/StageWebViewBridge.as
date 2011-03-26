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

		public var bridge:StageWebViewBridgeExternal;
		
		private static const ROOT_PATH:String = new File(new File( "app:/" ).nativePath).url;
	
		private var _view:StageWebView;
		private var _loadLocalURLFileStream:FileStream;
	
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
		public function StageWebViewBridge()
		{
			_view = new StageWebView();
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
		 * Loads a local htmlFile into the webview.
		 * Loads this file from the aplication directory and preprocess it.
		 * If a preprocesed version of the file don't exist, preprocess the
		 * file and save a version to the aplicationStorageDirectory.
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
			_loadLocalURLFileStream = new FileStream();			

			var fileName:String = url.split('applink:/')[1];
			var applicationDirectoryFile:File = new File(new File( "app:/"+fileName ).nativePath);
			var userCacheFile:File = File.applicationStorageDirectory.resolvePath( 'htmlcache/'+fileName );
			var updateCache:Boolean = false;  	
			if(!userCacheFile.exists ) 
			{	
				updateCache = true; 
			}
			else
			{
				if ( applicationDirectoryFile.modificationDate.getTime() > userCacheFile.modificationDate.getTime() )
				{
					updateCache = true;
				}
				else
				{
					updateCache = false; 
				}	
			}
			
			if( updateCache )
			{
				_loadLocalURLFileStream.open(applicationDirectoryFile, FileMode.READ);
				var fileContents:String = _loadLocalURLFileStream.readUTFBytes(_loadLocalURLFileStream.bytesAvailable).split('appfile:').join( ROOT_PATH ).split('<head>').join( '<head><script type="text/javascript">'+JSCODE+'</script>' );
				_loadLocalURLFileStream.close();
				
				_loadLocalURLFileStream.open(userCacheFile, FileMode.WRITE );
				_loadLocalURLFileStream.writeUTFBytes( fileContents );
				_loadLocalURLFileStream.close();			
			}
			_view.loadURL( new File( userCacheFile.nativePath ).url ); 
			
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
			text = text.split('appfile:').join( ROOT_PATH ).split('<head>').join( '<head><script type="text/javascript">'+JSCODE+'</script>' );
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