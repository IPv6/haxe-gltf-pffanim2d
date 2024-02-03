package starling.gltf;
import starling.display.DisplayObjectContainer;

class SSBaseProps {
	public function new(){};
	public var isDirty:Int = 0;
	public var x:Float = 0;
	public var y:Float = 0;
	public var pivotX:Float = 0;
	public var pivotY:Float = 0;
	public var scaleX:Float = 1;
	public var scaleY:Float = 1;
	public var rotation:Float = 0;
	public var alpha:Float = 1;
	public var visible:Bool = true;
	public function toString():String {
		return '[p(${x},${y})-(${pivotX},${pivotY}) s(${scaleX},${scaleY}) r${rotation} a${alpha}/${visible}]';
	}
}

class SSAnimNode extends SSBaseProps {
	public function new(){super();};
	public var sprite:DisplayObjectContainer = null;
	public var gltf_id:Int = 0;
	public var full_path:String = "";
	public var extras:Dynamic = null;
}