package pff.starling;

import pff.starling.PFFAnimManager.PFFAnimState;

class PFFTimeline {
	public var name:String = null;
	public var anims:Array<PFFAnimState> = null;
	public var timeCurrent:Float = 0.0;
	public var timeScale:Float = 1.0;
	public var gltfTimeMin:Float = -1.0;
	public var gltfTimeMax:Float = -1.0;
	public var anims_infl:Map<Int, Float> = new Map<Int, Float>();
	public function new(tname:String = null){
		static var tn_cnt = 0;
		tn_cnt++;
		if(tname == null){
			tname = 'tm_${tn_cnt}';
		}
		this.name = tname;
	};
	public function advanceTime(time:Float):Array<???> {
		// возврат активированных ивентов? или активация сразу
		return null;
	}
}