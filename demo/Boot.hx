package;

import openfl.system.Capabilities;
import openfl.system.System;
import openfl.errors.Error;
import openfl.geom.Rectangle;
import openfl.display3D.Context3DRenderMode;
import haxe.io.*;

import gltf.*;
import pff.starling.*;
import pff.starling.PFFAnimManager.PFFNodeProps;
import pff.starling.PFFAnimManager.PFFNodeState;
import pff.starling.PFFAnimManager.PFFAnimProps;
import pff.starling.PFFAnimManager.PFFAnimState;
import pff.starling.PFFTimeline.TimelineAction;
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
		var all_files = Assets.list(null);
		trace("- Loading assets", all_files);
		_assets = new AssetManager();
		_assets.verbose = true;
		// Enquening one-by-one top supply asset with proper name with extension
		for(pth in all_files){
			var pth_full = Assets.getPath(pth);
			// Path.directory(pth_full)
			_assets.enqueueSingle(pth_full, Path.withoutDirectory(pth_full));
		}
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
		var test_anims = 2; // 0; #if test_anim test_anims = 2; #end
		// test_scene_static, test_scene_anim: GLTF LOADING
		// Folder used for test in project.xml - assets
		var asset_obj = _assets.getObject("test_scene.gltf");
		// var asset_ba = _assets.getByteArray("root.gltf");
		// var asset_raw:String = asset_ba.readUTFBytes(asset_ba.length);
		var gltf_res:Utils.MapS2A = new Utils.MapS2A();
		gltf_res["root"] = asset_obj;
		var ext_list = PFFScene.extractExternalResources( "root", gltf_res );
		trace("- resources required by gLTF", ext_list);
		if(ext_list == null){
			trace("- gltf file missing");
			return;
		}
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
		gscene.gltf_load_verbose = true;
		// Custom loading options setup: gscene.<props> = ...
		var gltf_root = gscene.makeSceneTree("root", gltf_res);
		if(Utils.safeLen(gscene.gltf_load_warnings) > 0){
			trace("- loaded with warnings/errors", Utils.safeLen(gscene.gltf_load_warnings) );
		}else{
			trace("- loaded without warnings/errors");
		}
		if(gltf_root == null){
			trace("- no root");
			return;
		}
		gltf_root.x = _starling.stage.stageWidth * 0.5;
		gltf_root.y = _starling.stage.stageHeight * 0.5;
		_root.addChild(gltf_root);

		// test_scene_static, test_scene_anim: Test: compositions switch
		var activeUI = 1;
		gscene.addComposition("ui1",["ui1"],["ui2"]);
		gscene.addComposition("ui2",["ui2"],["ui1"]);
		gscene.activateComposition("ui1");
		Starling.current.juggler.repeatCall(()-> {
			activeUI = activeUI+1;
			if( (activeUI%2) == 1){
				gscene.activateComposition("ui1");
			}else{
				gscene.activateComposition("ui2");
			}
		}, 3.0);

		if(test_anims > 0){
			if(test_anims == 1){
				// test_scene_anim: direct apply animations at different times
				var allAnims = gscene.filterAnimsByName(["*"]);
				var allAnimStates:Array<PFFAnimState> = [];
				for (an in allAnims){
					var ans:PFFAnimState = new PFFAnimState(an, 0, 1);
					allAnimStates.push(ans);
				}
				var animTime = 0.0;
				Starling.current.juggler.repeatCall(()-> {
					for (ans in allAnimStates){
						ans.gltfTime = animTime;
					}
					gscene.applyAnimations(allAnimStates);
					animTime = (animTime+0.03)%2.0;
				}, 0.1);
			}
			if(test_anims == 2){
				// test_scene_anim: animation manager with meta-timeline
				var anims = new PFFAnimManager(gscene);
				// var timeline = PFFTimeline.makeTimelinePingPong();
				// var timeline = PFFTimeline.makeTimelinePlayAndStop();
				var timeline = PFFTimeline.makeTimelinePlayAndWrap(0.0);
				anims.playAnimsByName(["*"], timeline);
				// stopping all anims after 10 sec
				Starling.current.juggler.delayCall(()-> {
					var stop_action = TimelineAction.STOP_SMOOTH(1.0);
					// FADE_OUT: Not really stopping, influence==0 -> apply with zero effect
					// var stop_action = TimelineAction.FADE_OUT(1.0);
					anims.activateAction(stop_action, timeline);
				}, 10.0);
			}
		}
	}
}