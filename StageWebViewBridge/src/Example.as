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
package
{
	import com.bit101.components.PushButton;
	import com.bit101.components.TextArea;
	
	import es.xperiments.media.StageWebViewBridge;
	
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.LocationChangeEvent;
	import flash.events.MouseEvent;
	import flash.geom.Rectangle;
	import flash.media.StageWebView;
	import flash.system.Capabilities;
	import flash.text.TextField;
	
	
	
	[SWF(width="1024", height="768", frameRate="30", backgroundColor="#FFFFFF")]
	public class Example extends Sprite 
	{
		public var changeColorJSButton:PushButton;
		public var getTextAreaValueJSButton:PushButton;
		public var textarea:TextArea;
		public var webView:StageWebViewBridge;		 
		public var boxColor:Sprite = new Sprite();
		public static var instance:Example;
		public function Example()
		{ 
			super();

			instance = this;
			addEventListener(Event.ADDED_TO_STAGE, initUI );
		}
		private function initUI( e:Event ):void
		{
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE; 
			textarea = new TextArea( this, 10, 70 );
			
			StageWebViewBridge.DEBUGMODE=false;
			StageWebViewBridge.setRootFolder('html');
			
			webView = new StageWebViewBridge();
			webView.stage = this.stage;
			webView.viewPort = new Rectangle(0, 200, stage.stageWidth, 400);
			webView.loadLocalURL("applink:/index.html");

			changeColorJSButton = new PushButton(this, 10, 10, "Change HTML background color", onChangeColorJSButton);
			getTextAreaValueJSButton = new PushButton(this, 10, 40, "Get HTML TextArea value", onGetTextAreaValueJSButton);

			changeColorJSButton.width = 150;
			getTextAreaValueJSButton.width = 150;			
			textarea.width = 450;
			textarea.height = 100;

			
			addChild( changeColorJSButton );
			addChild( getTextAreaValueJSButton );
			addChild( textarea );
			
			// create boxColor
			boxColor = new Sprite();
			boxColor.x = 200;
			boxColor.y = 10;
			
			addChild( boxColor );
			changeBoxColor( '0xFF0000');
			//addJavascriptCallBacks();
			
			//textarea.text = Capabilities.os+'110101001'; 
			
			textarea.text = [ Capabilities.manufacturer,Capabilities.os,Capabilities.screenDPI, Capabilities.version ].join('\n');
			
		}
		private function addJavascriptCallBacks():void
		{
			//webView.bridge.addCallback("changeColorAS", changeBoxColor );
			//webView.bridge.addCallback("getTextAreaValueAS", getTextAreaValueAS );
		}
		
		private function getTextAreaValueAS( incomingText:String ):String
		{
			return textarea.text + ' ::: IncomingText = '+incomingText;
		}	
		
		private function changeBoxColor( color:String ):void
		{
			boxColor.graphics.clear();
			boxColor.graphics.beginFill( parseInt( color ) );
			boxColor.graphics.drawRect( 0,0,100,50);
			boxColor.graphics.endFill();
		}
		
		private function onChangeColorJSButton( e:Event ):void
		{
			var bgcolorlist:Array=new Array("#DFDFFF", "#FFFFBF", "#80FF80", "#EAEAFF", "#C9FFA8", "#F7F7F7","#DDDD00");
			var randomColor:String = bgcolorlist[Math.floor(Math.random()*bgcolorlist.length)];
			//webView.bridge.call('changeColorJS',null, randomColor);
			webView.loadURL("javascript:toto('pedro');");
		}
	
		private function onGetTextAreaValueJSButton( e:Event ):void
		{
			//webView.bridge.call('getTextAreaValueJS',onGetTextAreaValueJSDataReceived );
		}		
		private function onGetTextAreaValueJSDataReceived( value:String ):void
		{
			textarea.text = value;
		}	
	}
}