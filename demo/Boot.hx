package;

import openfl.system.Capabilities;
import openfl.system.System;
import openfl.errors.Error;
import openfl.geom.Rectangle;
import haxe.io.*;

import gltf.*;

import openfl.display3D.Context3DRenderMode;
import starling.gltf.*;
import starling.core.*;
import starling.display.*;
import starling.events.*;
import starling.assets.*;
import openfl.utils.Assets;
import starling.utils.RectangleUtil;
import starling.utils.StringUtil;
import starling.utils.Max;

class Boot extends openfl.display.Sprite
{
	private var _starling:Starling;
	private var _assets:AssetManager;
	private var _root:starling.display.Sprite;
	private var _openflStage:openfl.display.Stage;
	public function new()
	{
		super();
		_openflStage = stage;
		if (_openflStage != null) {
			startStarling();
		}else {
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		}
	}

	private function onAddedToStage(event:Dynamic):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		startStarling();
	}

	private function startStarling():Void
	{
		Starling.multitouchEnabled = true; // for Multitouch Scene
		_starling = new Starling(starling.display.Sprite, _openflStage, null, null, Context3DRenderMode.AUTO, "auto");
		_starling.stage.stageWidth = 1920;
		_starling.stage.stageHeight = 1080;
		_starling.enableErrorChecking = true;
		_starling.skipUnchangedFrames = true;
		_starling.supportBrowserZoom = true;
		_starling.supportHighResolutions = true;
		_starling.simulateMultitouch = true;
		_starling.addEventListener(Event.ROOT_CREATED, function():Void
		{
			// Delaying for fun
			_starling.juggler.delayCall( loadAssets, 1);
		});
		_openflStage.addEventListener(Event.RESIZE, onResize, false, Max.INT_MAX_VALUE, true);
		_starling.start();
	}

	private function loadAssets() {
		// var proj_path = Sys.getCwd();proj_path = StringTools.replace()
		// Path.normalize(Sys.getCwd()+"../test_scene/bg.jpg")
		trace("- Loading assets", Assets.getPath("test_scene/root.gltf"));
		_assets = new AssetManager();
		_assets.verbose = true;
		_assets.enqueue([
			Assets.getPath ("test_scene/bg.jpg"),
			Assets.getPath ("test_scene/root.bin"),
			Assets.getPath ("test_scene/root.gltf"),
			Assets.getPath ("test_scene/buttons_bt_exit.png"),
			Assets.getPath ("test_scene/buttons_bt_options.png"),
			Assets.getPath ("test_scene/buttons_bt_read.png"),
			Assets.getPath ("test_scene/logo_bg_title.png"),
		]);
		_assets.loadQueue(function(){
			trace("loadQueue finish, root:", _starling.root);
			_root = cast(_starling.root, starling.display.Sprite);
			showScene();
		},function(err:String){
			trace("loadQueue failed", err);
		});
	}

	public function showScene() {
		var bg_tex = _assets.getTexture("bg");
		var bg_img:starling.display.Image = new starling.display.Image(bg_tex);
		_root.addChild(bg_img);
	}

	private function onResize(e:openfl.events.Event):Void
	{
		try
		{
			if(_starling != null){
				var viewPort:Rectangle = RectangleUtil.fit(new Rectangle(0, 0, 1920, 1080), new Rectangle(0, 0, stage.stageWidth, stage.stageHeight));
				trace("Resizing viewPort", viewPort);
				_starling.viewPort = viewPort;
			}
		}
		catch(error:Error) {
			trace("Resizing viewPort failed", error);
		}
	}
}