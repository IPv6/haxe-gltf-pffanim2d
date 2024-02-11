package pff.starling;

import starling.core.*;
import starling.display.DisplayObject;
import starling.display.DisplayObjectContainer;
import starling.animation.*;

import pff.starling.PFFScene.PFFScene;
import pff.starling.PFFTimeline.PFFTimeline;

class PFFNodeProps {
	public function new(){};
	public var x:Float = 0;
	public var y:Float = 0;
	public var pivotX:Float = 0;
	public var pivotY:Float = 0;
	public var scaleX:Float = 1;
	public var scaleY:Float = 1;
	public var rotation:Float = 0;
	public var bbox_w:Float = 0;
	public var bbox_h:Float = 0;
	public var alpha_self:Float = 1;
	public var visible:Bool = true;
	public function toString():String {
		return '[p(${x},${y})-(${pivotX},${pivotY}) s(${scaleX},${scaleY}) r${rotation} a${alpha_self}/${visible}]';
	}
}

class PFFNodeState {
	public function new(){};
	public var props:PFFNodeProps = null;
	public var sprite:starling.display.DisplayObject = null;// Sprite or Quad (clip mask)
	public var gltf_id:Int = -1;
	public var gltf_parent_id:Int = -1;
	public var full_path:String = "";
	public var customprops:Dynamic = null;

	public var z_order:Float = 0;
	// public var alpha_mask:Float = 1;
	public var xy_dirty:Int = 0;
	public var sxsy_dirty:Int = 0;
	public var r_dirty:Int = 0;
	public var a_dirty:Int = 0;
	public function toString():String {
		return this?.props.toString();
	}
}

class PFFAnimProps {
	public function new(){};
	public var full_path:String = "";
	public var gltf_id:Int = -1;
	public var gltfTimeMin:Float = 0.0;
	public var gltfTimeMax:Float = 0.0;
	public var timestamps:Array< Array<Float> > = null;
}

class PFFAnimState {
	public function new(a:PFFAnimProps, t:Float, i:Float){
		anim = a;gltfTime=t;influence=i;
	};
	public var anim:PFFAnimProps = null;
	public var gltfTime:Float = 0.0;
	public var influence:Float = 0.0;
}

/**
* PFFAnimManager supports convenience grouping and control over animations
* - automatic Juggler activation/deactivation
* - normalized time (0.0 = animation start, 1.0 = animation end)
* - animation speed, possibility to "revert" animation
* - meta timelines with "events" and "commands" - can be used to make "ping-pong","loop" and other time behaviour customization
**/
class PFFAnimManager implements IAnimatable {
	public var scene:PFFScene;
	public var juggler_id:Int = -1;
	public var timelines:Array<PFFTimeline> = [];
	public function new(pffsc:PFFScene){
		scene = pffsc;
	};
	public function playAnimsByName(names:Utils.ArrayS, withTimeline:PFFTimeline):Bool {
		var anims = scene.filterAnimsByName(names,false);
		if(anims.length == 0){
			// no anims found, but probably just compositions
			var compos = 0;
			for (nm in names){
				if(scene.activateComposition(nm)){
					compos++;
				}
			}
			return compos>0;
		}
		withTimeline.setAnims(anims);
		return playTimeline(withTimeline);
	}
	public function playTimeline(timeline:PFFTimeline):Bool {
		if(Utils.safeLen(timeline?.anims) == 0){
			// Timeline have no content
			return false;
		}
		if(juggler_id < 0){
			juggler_id = Starling.current.juggler.add(this);
		}
		return true;
	}
	public function findTimeline(tname:String): PFFTimeline {
		for(ts in timelines){
			if(ts.name == tname){
				return ts;
			}
		}
		return null;
	}
	public function advanceTime(delta_sec:Float):Void {
		var activeAnims:Array<PFFAnimState> = [];
		for(ts in timelines){
			ts.advanceTime(delta_sec);
			if(ts.isActive()){
				for(an in ts.anims){
					activeAnims.push(an);
				}
			}
		}
		if(activeAnims.length > 0){
			scene.applyAnimations(activeAnims);
		}else if(juggler_id >= 0){
			trace("stopping animMan");
			Starling.current.juggler.removeByID(juggler_id);
			juggler_id = -1;
		}
	}
}

