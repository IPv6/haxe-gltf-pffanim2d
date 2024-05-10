package pff.starling;

import pff.starling.PFFAnimManager.PFFAnimProps;
import pff.starling.PFFAnimManager.PFFAnimState;

enum abstract TimelineActivationOrder(Int) from Int to Int {
	var TOP = 1;
	var BOTTOM;
	var REPLACE;
}

enum abstract TimelineDirection(Int) from Int to Int {
	var BACKWARD = -1;
	var ANY = 0;
	var FORWARD = 1;
}

enum abstract TimelineTimeMode(Int) from Int to Int {
	var GLTF = 1;
	var RATIO;
	var GLTF_ONCE;
	var NEVER;
}

enum TimelineAction {
	STOP;// Timeline timeScale = 0, same as SPEED(0)
	SPEED( new_speed:Float );// Timeline timeScale to any value
	JUMP( to_time:Float, time_mode:TimelineTimeMode );
	STOP_SMOOTH( fade_sec:Float );// Timeline timeScale ???->0.0
	FADE_IN( fade_sec:Float );// Timeline influence 0->1
	FADE_OUT( fade_sec:Float );// Timeline influence ???->0. Not a stopping action! zero influence == apply with zero effect, but time still go on
	PASS; // Do nothing, can be used to triggering callbacks/etc
}

class TimelineEvent {
	public function new(on_time:Float, time_mode:TimelineTimeMode, action:TimelineAction, target:String = null){
		trigger_time = on_time;
		trigger_time_mode = time_mode;
		event_action = action;
		event_timeline = target;
	};
	public var trigger_time:Float = 0;
	public var trigger_time_mode:TimelineTimeMode = GLTF_ONCE;
	public var trigger_limit_by_direction:TimelineDirection = ANY;
	public var event_action:TimelineAction = STOP;
	public var event_timeline:String = null;// By default its timeline that holds event. But event can affect different timeline (by name)
	public var event_payload:Any = null;// Anything (for triggerred event processing)

	public var target_timeline:PFFTimeline = null;// Cached value of event timeline (found by name)
}

/**
* PFFTimeline groups animations that share time scale and behaviour
* Each PFFTimeline name should have unique, PFFAnimManager can alter timeline behaviour by name
* TimelineEvents can be used for "sequences" of animations (loop, ping-ping, etc)
**/
class PFFTimeline {
	public var name:String = null;
	public var anims:Array<PFFAnimState> = null;
	public var events:Array<TimelineEvent> = null;
	public var timeScale:Float = 1.0;
	public var timeCurrent:Float = 0.0;
	public var timePhase:Float = 0.0;
	public var influence:Float = 1.0;
	public var gltfTimeMin:Float = -1.0;
	public var gltfTimeMax:Float = -1.0;
	public var onBeforePlay:(PFFTimeline)->Void = null;
	public var onEventTriggered:(PFFTimeline, TimelineEvent)->Void = null;
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
		// Must set time to initalize gltfMin/gltgMax
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
	public function setInfluence(inf:Float):Bool {
		influence = inf;
		return true;
	}
	public function isActive():Bool {
		if(Math.abs(timeScale) < Utils.GLM_EPSILON){
			return false;
		}
		return true;
	}
	public function getGltfTimeByRatio(normalizedTime:Float): Float {
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
		var gltfTime = gltfTimeMin + (gltfTimeMax-gltfTimeMin) * normalizedTime;
		return gltfTime;
	}
	public function setTimeByGltfTime(gltfTime:Float): Bool {
		timeCurrent = gltfTime;
		return true;
	}
	public function setTimeByRatio(normalizedTime:Float): Bool {
		if(Utils.safeLen(anims) == 0){
			// Timeline not attached to animation
			// not possible to recalc in gltfTime
			return false;
		}
		var gltfTime = getGltfTimeByRatio(normalizedTime);
		return setTimeByGltfTime(gltfTime);
	}
	var triggered_events:Array<TimelineEvent> = [];
	public function advanceTime(delta_sec:Float):Array<TimelineEvent> {
		delta_sec = delta_sec*timeScale;
		if(Math.abs(delta_sec) < Utils.GLM_EPSILON){
			return null;
		}
		triggered_events.resize(0);
		var timeCurrent_next = timeCurrent+delta_sec;
		if(this.events != null){
			for(ev in this.events){
				if(ev.trigger_time_mode	== NEVER){
					continue;
				}
				if(ev.trigger_time_mode	== GLTF_ONCE){
					triggered_events.push(ev);
					ev.trigger_time_mode = NEVER;
					continue;
				}
				if(ev.trigger_limit_by_direction == FORWARD && delta_sec < 0.0){
					continue;
				}
				if(ev.trigger_limit_by_direction == BACKWARD && delta_sec > 0.0){
					continue;
				}
				var trigger_time = ev.trigger_time;
				if(ev.trigger_time_mode	== RATIO){
					trigger_time = getGltfTimeByRatio(ev.trigger_time);
				}
				if(delta_sec > 0){
					if(trigger_time >= timeCurrent && trigger_time < timeCurrent_next){
						triggered_events.push(ev);
					}
				}else{
					if(trigger_time > timeCurrent_next && trigger_time <= timeCurrent){
						triggered_events.push(ev);
					}
				}
			}
		}
		timeCurrent = timeCurrent_next;
		for(an in anims){
			an.influence = influence;
			an.gltfTime = timeCurrent+timePhase;
		}
		return triggered_events;
	}

	public static function makeTimelinePlayAndStop():PFFTimeline {
		var res = new PFFTimeline();
		var stopAtEnd = new TimelineEvent(1.0, RATIO, STOP);
		res.setEvents([stopAtEnd]);
		return res;
	}
	public static function makeTimelinePlayAndWrap():PFFTimeline {
		var res = new PFFTimeline();
		var wrapAtEnd = new TimelineEvent(1.0, RATIO, JUMP(0.0, RATIO));
		res.setEvents([wrapAtEnd]);
		return res;
	}
	public static function makeTimelinePingPong():PFFTimeline {
		var res = new PFFTimeline();
		var toogleAtStart = new TimelineEvent(0.0, RATIO, SPEED(1.0));
		toogleAtStart.trigger_limit_by_direction = BACKWARD;
		var toogleAtEnd = new TimelineEvent(1.0, RATIO, SPEED(-1.0));
		toogleAtEnd.trigger_limit_by_direction = FORWARD;
		res.setEvents([toogleAtStart, toogleAtEnd]);
		return res;
	}
}