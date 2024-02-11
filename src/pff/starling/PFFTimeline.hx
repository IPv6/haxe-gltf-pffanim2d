package pff.starling;

import pff.starling.PFFAnimManager.PFFAnimProps;
import pff.starling.PFFAnimManager.PFFAnimState;

/**
* PFFTimeline groups animations that share time scale and behaviour
* Each PFFTimeline should have unique, PFFAnimManager can alter timeline behaviour by name
**/
class PFFTimeline {
	public var name:String = null;
	public var anims:Array<PFFAnimState> = null;
	public var events:Array<Any> = null;
	public var timeScale:Float = 1.0;
	public var timeCurrent:Float = -1.0;// Inits to gltfTimeMin
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
	public function advanceTime(time:Float):Array<Any> {
		// возврат активированных ивентов? или активация сразу
		return null;
	}
	public function isActive():Bool {
		if(Math.abs(timeScale) < Utils.GLM_EPSILON){
			return false;
		}
		return true;
	}
	public function setAnims(anims:Array<PFFAnimProps>): Bool {
		var animStates:Array<PFFAnimState> = [];
		for (an in anims){
			var ans:PFFAnimState = {
				anim: an,
				infl: 1.0,
				gltfTime: timeCurrent,
			}
			animStates.push(ans);
		}
		this.anims = animStates;
		return true;
	}
	public function setTimeScale(scale:Float):Bool {
		timeScale = scale;
		return true;
	}
	public function setTimeNrm(normalizedTime:Float): Bool {
		if(gltfTimeMin < 0 && gltfTimeMax < 0){
			// inits...
		}
		timeCurrent = gltfTimeMin + (gltfTimeMax-gltfTimeMin) * normalizedTime;
		return true;
	}
}