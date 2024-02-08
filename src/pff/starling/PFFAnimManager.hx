package pff.starling;
import starling.display.DisplayObject;
import starling.display.DisplayObjectContainer;
import starling.animation.*;

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

class PFFAnimState {
	public function new(){};
	public var full_path:String = "";
	public var gltf_id:Int = -1;
	public var gltfTime:Float = 0.0;
	public var gltfTimeMin:Float = 0.0;
	public var gltfTimeMax:Float = 0.0;
	public var infl:Float = 1.0;
}

class PFFAnimNode extends PFFNodeProps {
	public function new(){super();};
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
	public var mask_dirty:Int = 0;
}

class PFFAnimManager implements IAnimatable {
	public function new(){};
	public function advanceTime(time:Float):Void {
		
	}
}

