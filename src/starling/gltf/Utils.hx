package starling.gltf;

import haxe.io.Bytes;
import haxe.ds.Vector;
import starling.display.Stage;
import starling.display.Sprite;
import starling.display.DisplayObject;
import openfl.utils.ByteArray;

typedef VectorF = Vector<Float>;
typedef ArrayF = Array<Float>;
typedef ArrayI = Array<Int>;
typedef ArrayS = Array<String>;
typedef ArrayA = Array<Any>;
typedef MapS2A = Map<String,Any>;
abstract Either<T1, T2>(Dynamic) from T1 from T2 to T1 to T2 {}

class SpriteProps {
	public function new(){};
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

class Utils {
	private function new(){};

	static public function safeLen(anything:Dynamic):Int {
		var cnt : Int = 0;
		if (anything == null )
		{
			return 0;
		}
		else if (Std.isOfType(anything, String))
		{
			cnt = anything.length;
		}
		else if(Reflect.field(anything, "iterator") != null){// Iterables.isIterable(anything)
			cnt = 0;
			var anything_any:Iterable<Dynamic> = cast anything;
			for(field_val in anything_any){
				cnt = cnt + 1;
			}
		}
		else if(Reflect.field(anything, "hasNext") != null){// Iterators.isIterator(anything)
			cnt = 0;
			var anything_any:Iterator<Dynamic> = cast anything;
			for(field_val in anything_any){
				cnt = cnt + 1;
			}
		}else if(Std.isOfType(anything,haxe.ds.StringMap)){
			cnt = safeLen(anything.keys());
		}
		else if (Std.isOfType(anything, Array) || Std.isOfType(anything, List))
		{
			cnt = anything.length;
		}
		else if (Std.isOfType(anything, Dynamic))
		{
			for (prop in Reflect.fields(anything))
			{
				cnt++;
			}
		}
		return cnt;
	}

	static public function xyz2xyzScaled(pos:Either<ArrayF,VectorF>, scale:Float = 1.0):ArrayF {
		if(pos == null){
			return [0.0,0.0,0.0];
		}
		return [pos[0]*scale, pos[1]*scale, pos[2]*scale];
	}

	static public function quaternion2euler(quat:Either<ArrayF,VectorF>):ArrayF {
		// quat expected to be NORMALIZED
		// https://en.wikipedia.org/wiki/Conversion_between_quaternions_and_Euler_angles
		// Quat math: https://github.com/hamaluik/haxe-glm/blob/master/src/glm/Quat.hx

		if(quat == null){
			return [0.0, 0.0, 0.0];
		}
		var qx = quat[0];
		var qy = quat[1];
		var qz = quat[2];
		var qw = quat[3];

		// roll (x-axis rotation)
		var sinr_cosp = 2 * (qw * qx + qy * qz);
		var cosr_cosp = 1 - 2 * (qx * qx + qy * qy);
		var roll = Math.atan2(sinr_cosp, cosr_cosp);
	
		// pitch (y-axis rotation)
		var sinp = Math.sqrt(1 + 2 * (qw * qy - qx * qz));
		var cosp = Math.sqrt(1 - 2 * (qw * qy - qx * qz));
		var pitch = 2 * Math.atan2(sinp, cosp) - Math.PI / 2;
	
		// yaw (z-axis rotation)
		var siny_cosp = 2 * (qw * qz + qx * qy);
		var cosy_cosp = 1 - 2 * (qy * qy + qz * qz);
		var yaw = Math.atan2(siny_cosp, cosy_cosp);
	
		return [roll, pitch, yaw];
	}

	// openfl.utils.ByteArray -> haxe.io.Bytes
	static public function openflByteArray2haxeBytes(byteArray:Null<ByteArray>):Bytes {
		if(byteArray == null){
			return Bytes.alloc(0);
		}
		byteArray.position = 0;
		var bytes:Bytes = Bytes.alloc(byteArray.length);
		while (byteArray.bytesAvailable > 0) {
			bytes.set(byteArray.position, byteArray.readByte());
		}
		return bytes;
	}

	static public function dumpSprite(spr:DisplayObject, props:SpriteProps):SpriteProps {
		if(props == null){
			props = new SpriteProps();
		}
		props.visible = spr.visible;
		props.alpha = spr.alpha;
		props.x = spr.x;
		props.y = spr.y;
		props.pivotX = spr.pivotX;
		props.pivotY = spr.pivotY;
		props.scaleX = spr.scaleX;
		props.scaleY = spr.scaleY;
		props.rotation = spr.rotation;
		return props;
	}
	static public function undumpSprite(spr:DisplayObject, props:SpriteProps):Void {
		spr.visible = props.visible;
		spr.alpha = props.alpha;
		spr.x = props.x;
		spr.y = props.y;
		spr.pivotX = props.pivotX;
		spr.pivotY = props.pivotY;
		spr.scaleX = props.scaleX;
		spr.scaleY = props.scaleY;
		spr.rotation = props.rotation;
	}
}