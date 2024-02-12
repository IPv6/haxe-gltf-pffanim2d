package pff.starling;

import pff.starling.PFFAnimManager.PFFAnimProps;
import pff.starling.PFFAnimManager.PFFAnimState;

enum abstract TimelineActivationOrder(Int) from Int to Int {
	var TOP = 1;
	var BOTTOM;
	var REPLACE;
}

enum abstract TimelineTimeMode(Int) from Int to Int {
	var GLTF = 1;
	var RATIO;
	var ONCE;
}

enum TimelineAction {
	STOP;// same as CHANGE_SPEED to 0
	SPEED( new_speed:Float );
	JUMP( to_time:Float, time_mode:TimelineTimeMode );
}

class TimelineEvent {
	public function new(on_time:Float, time_mode:TimelineTimeMode, action:TimelineAction, target:String = null){
		trigger_time = on_time;
		trigger_time_mode = time_mode;
		event_action = action;
		target_timeline = target;
	};
	public var trigger_time:Float = 0;
	public var trigger_time_mode:TimelineTimeMode = ONCE;
	public var event_action:TimelineAction = STOP;
	public var target_timeline:String = null;
}

/**
* PFFTimeline groups animations that share time scale and behaviour
* Each PFFTimeline should have unique, PFFAnimManager can alter timeline behaviour by name
**/
class PFFTimeline {
	public var name:String = null;
	public var anims:Array<PFFAnimState> = null;
	public var events:Array<TimelineEvent> = null;
	public var timeScale:Float = 1.0;
	public var timeCurrent:Float = 0.0;
	public var timePhase:Float = 0.0;
	public var gltfTimeMin:Float = -1.0;
	public var gltfTimeMax:Float = -1.0;
	public function new(tname:String = null){
		static var tn_cnt = 0;
		tn_cnt++;
		if(tname == null){
			tname = 'tm_${tn_cnt}';
		}
		this.name = tname;
	};
	public function setAnims(animp:Array<PFFAnimProps>): Bool {
		var animStates:Array<PFFAnimState> = [];
		for (an in animp){
			var ans:PFFAnimState = new PFFAnimState(an, 0.0, 1);
			animStates.push(ans);
		}
		this.anims = animStates;
		setTimeByRatio(0.0);
		return true;
	}
	public function setEvents(elist:Array<TimelineEvent>): Bool {
		events = elist;
		return true;
	}
	public function setTimeScale(scale:Float):Bool {
		// 0.0 = pause, 1.0/-1.0 = play forward/backward
		timeScale = scale;
		return true;
	}
	public function isActive():Bool {
		if(Math.abs(timeScale) < Utils.GLM_EPSILON){
			return false;
		}
		return true;
	}
	public function setTimeByRatio(normalizedTime:Float): Bool {
		if(Utils.safeLen(anims) == 0){
			return false;
		}
		if(gltfTimeMin < 0 && gltfTimeMax < 0){
			for (ans in anims){
				if(gltfTimeMin < 0 || gltfTimeMax < 0){
					gltfTimeMin = ans.anim.gltfTimeMin;
					gltfTimeMax = ans.anim.gltfTimeMax;
					continue;
				}
				gltfTimeMin = Math.min(gltfTimeMin, ans.anim.gltfTimeMin);
				gltfTimeMax = Math.max(gltfTimeMax, ans.anim.gltfTimeMax);
			}
		}
		// if(Math.abs(gltfTimeMax-gltfTimeMin) < Utils.GLM_EPSILON){
		// 	return false;
		// }
		timeCurrent = gltfTimeMin + (gltfTimeMax-gltfTimeMin) * normalizedTime;
		return true;
	}
	public function advanceTime(delta_sec:Float):Array<Any> {
		delta_sec = delta_sec*timeScale;
		if(Math.abs(delta_sec) < Utils.GLM_EPSILON){
			return null;
		}
		timeCurrent += delta_sec;
		for(an in anims){
			an.gltfTime = timeCurrent+timePhase;
		}
		return null;
	}

}