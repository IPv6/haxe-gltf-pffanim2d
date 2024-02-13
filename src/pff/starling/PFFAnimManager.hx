package pff.starling;

import starling.core.*;
import starling.display.DisplayObject;
import starling.display.DisplayObjectContainer;
import starling.animation.*;

import pff.starling.PFFScene.PFFScene;
import pff.starling.PFFTimeline.PFFTimeline;
import pff.starling.PFFTimeline.TimelineActivationOrder;
import pff.starling.PFFTimeline.TimelineEvent;
import pff.starling.PFFTimeline.TimelineAction;

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
	public function playAnimsByName(names:Utils.ArrayS, withTimeline:PFFTimeline, activationOrder:TimelineActivationOrder = REPLACE):Bool {
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
		return playTimeline(withTimeline, activationOrder);
	}
	public function removeTimeline(timeline:PFFTimeline): Bool {
		if(timeline == null){
			// Full reset, drop all
			timelines.resize(0);
			return true;
		}
		return timelines.remove(timeline);
	}
	public function playTimeline(timeline:PFFTimeline, activationOrder:TimelineActivationOrder = REPLACE):Bool {
		if(Utils.safeLen(timeline?.anims) == 0){
			// Timeline have no content
			return false;
		}
		switch activationOrder{
			case REPLACE:
				timelines = [timeline];
			case TOP:
				timelines.push(timeline);
			case BOTTOM:
				timelines.unshift(timeline);
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
	public function flushInactive():Int {
		var flushed = 0;
		var active_timelines:Array<PFFTimeline> = [];
		for(ts in timelines){
			if(ts.isActive()){
				active_timelines.push(ts);
			}else{
				flushed++;
			}
		}
		this.timelines = active_timelines;
		return flushed;
	}

	var activeAnims:Array<PFFAnimState> = [];
	var activeEvents:Array<TimelineEvent> = [];
	public function advanceTime(delta_sec:Float):Void {
		// no returns, juggler must stop if no anims
		for(ts in timelines){
			var triggeredEvent = ts.advanceTime(delta_sec);
			if(triggeredEvent != null){
				for(ev in triggeredEvent){
					if(ev.event_timeline == null){
						if(ev.last_triggered_at == null){
							ev.last_triggered_at = ts;
						}
					}else if(ev.last_triggered_at == null || ev.last_triggered_at.name != ev.event_timeline){
						ev.last_triggered_at = findTimeline(ev.event_timeline);
					}
					activeEvents.push(ev);
				}
			}
			if(ts.isActive()){
				for(an in ts.anims){
					activeAnims.push(an);
				}
			}
		}
		for(ev in activeEvents){
			activateAction(ev.event_action, ev.last_triggered_at);
		}
		if(activeAnims.length > 0){
			scene.applyAnimations(activeAnims);
		}else if(juggler_id >= 0){
			scene.log_i("PFFAnimManager: Stopping, no active animations");
			Starling.current.juggler.removeByID(juggler_id);
			juggler_id = -1;
		}
		activeAnims.resize(0);
		activeEvents.resize(0);
	}

	/**
	* Timeline behaviour change
	* can be used to manually stop/play/revert/etc animation at any time
	**/
	public function activateAction(action:TimelineAction, target_timeline:PFFTimeline):Bool {
		if(target_timeline == null){
			return false;
		}
		// scene.log_i('PFFAnimManager: Activating animation event: ${action}, ${target_timeline.name}');
		switch (action) {
			case STOP:
				target_timeline.setTimeScale(0.0);
			case SPEED(new_speed):
				target_timeline.setTimeScale(new_speed);
			case JUMP(to_time, time_mode):
				if(time_mode == RATIO){
					target_timeline.setTimeByRatio(to_time);
				}else{
					target_timeline.setTimeByGltfTime(to_time);
				}
			case STOP_SMOOTH(fade_sec):
				var tween = new Tween(target_timeline, fade_sec);
				tween.animate("timeScale", 0.0);
				Starling.current.juggler.add(tween);
			case FADE_IN(fade_sec):
				var tween = new Tween(target_timeline, fade_sec);
				target_timeline.setInfluence(0.0);
				tween.animate("influence", 1.0);
				Starling.current.juggler.add(tween);
			case FADE_OUT(fade_sec):
				var tween = new Tween(target_timeline, fade_sec);
				tween.animate("influence", 0.0);
				Starling.current.juggler.add(tween);
		}
		return true;
	}
}

