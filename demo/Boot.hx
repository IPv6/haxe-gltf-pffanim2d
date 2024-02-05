package;

import openfl.system.Capabilities;
import openfl.system.System;
import openfl.errors.Error;
import openfl.geom.Rectangle;
import openfl.display3D.Context3DRenderMode;
import haxe.io.*;

import gltf.*;
import pff.starling.*;
import openfl.utils.Assets;

import starling.core.*;
import starling.display.*;
import starling.events.*;
import starling.assets.*;
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
			_starling.juggler.delayCall( loadAssets, 1.0);
		});
		_openflStage.addEventListener(Event.RESIZE, onResize, false, Max.INT_MAX_VALUE, true);
		_starling.start();
	}
	private function onResize(e:openfl.events.Event):Void{
		try {
			if(_starling != null){
				var viewPort:Rectangle = RectangleUtil.fit(new Rectangle(0, 0, 1920, 1080), new Rectangle(0, 0, stage.stageWidth, stage.stageHeight));
				trace("Resizing viewPort", viewPort);
				_starling.viewPort = viewPort;
			}
		}catch(error:Error) {
			trace("Resizing viewPort failed", error);
		}
	}

	private function loadAssets() {
		// var proj_path = Sys.getCwd();proj_path = StringTools.replace(...); Path.normalize(Sys.getCwd()+"../test_scene/bg.jpg")
		// var appDir:File = File.applicationDirectory;appDir.resolvePath("test_scene/root.gltf")
		trace("- Loading assets", Assets.getPath("test_scene/root.gltf"));
		_assets = new AssetManager();
		_assets.verbose = true;
		// Enquening one-by-one top supply asset with proper name with extension
		_assets.enqueueSingle(Assets.getPath ("test_scene/root.bin"),"root.bin");
		_assets.enqueueSingle(Assets.getPath ("test_scene/root.gltf"),"root.gltf");
		_assets.enqueueSingle(Assets.getPath ("test_scene/bg.jpg"),"bg.jpg");
		_assets.enqueueSingle(Assets.getPath ("test_scene/logo_bg_title.png"),"logo_bg_title.png");
		_assets.enqueueSingle(Assets.getPath ("test_scene/buttons_bt_read.png"),"buttons_bt_read.png");
		_assets.enqueueSingle(Assets.getPath ("test_scene/buttons_bt_options.png"),"buttons_bt_options.png");
		_assets.enqueueSingle(Assets.getPath ("test_scene/buttons_bt_exit.png"),"buttons_bt_exit.png");
		_assets.loadQueue(function(){
			_root = cast(_starling.root, starling.display.Sprite);
			trace("loadQueue finished");
			showScene();
		},function(err:String){
			trace("loadQueue failed", err);
		});
	}

	public function showScene() {
		for(apt in [AssetType.TEXTURE, AssetType.SOUND, AssetType.OBJECT, AssetType.XML_DOCUMENT, AssetType.BYTE_ARRAY, AssetType.TEXTURE_ATLAS]){
			trace("showScene: Loaded assets",apt,_assets.getAssetNames(apt));
		}
		// var bg_tex = _assets.getTexture("bg.jpg");
		// var bg_img:starling.display.Image = new starling.display.Image(bg_tex);
		// _root.addChild(bg_img);

		// GLTF MENUTEST
		var asset_obj = _assets.getObject("root.gltf");
		// var asset_ba = _assets.getByteArray("root.gltf");
		// var asset_raw:String = asset_ba.readUTFBytes(asset_ba.length);
		var gltf_res:Utils.MapS2A = new Utils.MapS2A();
		gltf_res["root"] = asset_obj;
		var ext_list = PFFScene.extractExternalResources( "root", gltf_res );
		trace("- resources required by gLTF", ext_list);
		for(res_path in ext_list){
			var asset_tex = _assets.getTexture(res_path);
			if(asset_tex != null){
				gltf_res[res_path] = asset_tex;
				continue;
			}
			var asset_ba = _assets.getByteArray(res_path);
			if(asset_ba != null){
				gltf_res[res_path] = asset_ba;
				continue;
			}
		}
		var gscene = new PFFScene();
		// Custom loading options setup: gscene.<props> = ...
		var gltf_root = gscene.createSceneTree("root", gltf_res, null);
		trace("- loading warnings/errors", gscene.gltf_load_warnings);
		if(gltf_root != null){
			gltf_root.x = _starling.stage.stageWidth * 0.5;
			gltf_root.y = _starling.stage.stageHeight * 0.5;
			_root.addChild(gltf_root);
		}
	}
}