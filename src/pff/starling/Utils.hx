package pff.starling;

import pff.starling.PFFAnimManager.PFFNodeProps;
import pff.starling.PFFAnimManager.PFFNodeState;

import haxe.io.Bytes;
import haxe.ds.Vector;
import starling.display.Stage;
import starling.display.Sprite;
import openfl.utils.ByteArray;
import starling.display.DisplayObject;
import starling.display.DisplayObjectContainer;

typedef VectorF = Vector<Float>;
typedef ArrayF = Array<Float>;
typedef ArrayI = Array<Int>;
typedef ArrayS = Array<String>;
typedef ArrayA = Array<Any>;
typedef MapS2A = Map<String,Any>;
// same as https://api.haxe.org/haxe/ds/index.html 'Either'... but Dynamic as a base
abstract Either<T1, T2>(Dynamic) from T1 from T2 to T1 to T2 {}
// Taken from https://github.com/HaxeFoundation/haxe/blob/4.3.3/std/haxe/ds/Vector.hx to detect Vector values
private typedef VectorData<T> =
	#if flash10
	flash.Vector<T>
	#elseif neko
	neko.NativeArray<T>
	#elseif cs
	cs.NativeArray<T>
	#elseif java
	java.NativeArray<T>
	#elseif lua
	lua.Table<Int, T>
	#elseif eval
	eval.Vector<T>
	#else
	Array<T>
	#end;

class Utils {
	private function new(){};

	static public function safeLen(anything:Dynamic):Int {
		var cnt : Int = 0;
		if (anything == null){
			return 0;
		}else if (Std.isOfType(anything, String)){
			cnt = anything.length;
		}else if (Std.isOfType(anything, VectorData)){// haxe.ds.Vector
			cnt = anything.length;
		}else if (Std.isOfType(anything, Array) || Std.isOfType(anything, List)){
			cnt = anything.length;
		}else if(Std.isOfType(anything,haxe.ds.StringMap)){
			cnt = safeLen(anything.keys());
		}else if(Reflect.field(anything, "iterator") != null){// Iterables.isIterable(anything)
			cnt = 0;
			var anything_any:Iterable<Dynamic> = cast anything;
			for(field_val in anything_any){
				cnt = cnt + 1;
			}
		}else if(Reflect.field(anything, "hasNext") != null){// Iterators.isIterator(anything)
			cnt = 0;
			var anything_any:Iterator<Dynamic> = cast anything;
			for(field_val in anything_any){
				cnt = cnt + 1;
			}
		}else if (Std.isOfType(anything, Dynamic)){
			for (prop in Reflect.fields(anything))
			{
				cnt++;
			}
		}
		return cnt;
	}

	static inline public function vec2vecScaled(a:Either<ArrayF,VectorF>, mult:Float, dest:VectorF):VectorF {
		if(a == null){
			a = new VectorF(3,0);
		}
		var a_len = safeLen(a);
		for(vi in 0...a_len){
			dest[vi] = a[vi] * mult;
		}
		return dest;
	}
	static inline public function vec2vecLerped(a:Either<ArrayF,VectorF>, b:Either<ArrayF,VectorF>, t:Float, dest:VectorF):VectorF {
		var a_len = safeLen(a);
		for(vi in 0...a_len){
			dest[vi] = (1.0-t)*a[vi] + t*b[vi];
		}
		return dest;
	}
	static inline public function f2fLerped(a:Float, b:Float, t:Float):Float {
		var dest = (1.0-t)*a + t*b;
		return dest;
	}

	// Quat math: https://github.com/hamaluik/haxe-glm/blob/master/src/glm/Quat.hx
	static public var GLM_EPSILON:Float = 0.0000001;
	static public var GLM_SQRT2:Float =  1.41421356237309504880; // sqrt(2)
	static public function quat2euler(quat:Either<ArrayF,VectorF>):ArrayF {
		// Expected to return COPY. Quat expected to be NORMALIZED.
		// https://en.wikipedia.org/wiki/Conversion_between_quaternions_and_Euler_angles
		// Must match Blender Quaternion to EulerXYZ (For Y-up rotations)
		// https://github.com/dfelinto/blender/blob/87a0770bb969ce37d9a41a04c1658ea09c63933a/source/blender/blenlib/intern/math_rotation.c#L1332
		if(quat == null){
			return [0.0, 0.0, 0.0];
		}
		var qx = quat[0];
		var qy = quat[1];
		var qz = quat[2];
		var qw = quat[3];
		// // roll (x-axis rotation)
		// var sinr_cosp = 2 * (qw * qx + qy * qz);
		// var cosr_cosp = 1 - 2 * (qx * qx + qy * qy);
		// var roll = Math.atan2(sinr_cosp, cosr_cosp);
		// // pitch (y-axis rotation)
		// var sinp = Math.sqrt(1 + 2 * (qw * qy - qx * qz));
		// var cosp = Math.sqrt(1 - 2 * (qw * qy - qx * qz));
		// var pitch = 2 * Math.atan2(sinp, cosp) - Math.PI / 2;
		// // yaw (z-axis rotation)
		// var siny_cosp = 2 * (qw * qz + qx * qy);
		// var cosy_cosp = 1 - 2 * (qy * qy + qz * qz);
		// var yaw = Math.atan2(siny_cosp, cosy_cosp);
		// return [roll, pitch, yaw];
		// ====================
		// Blender quat_to_mat3 https://github.com/dfelinto/blender/blob/87a0770bb969ce37d9a41a04c1658ea09c63933a/source/blender/blenlib/intern/math_rotation.c#L180
		var q0:Float, q1:Float, q2:Float, q3:Float, qda:Float, qdb:Float, qdc:Float, qaa:Float, qab:Float, qac:Float, qbb:Float, qbc:Float, qcc:Float;
		var q0 = GLM_SQRT2 * qw;//q[0];
		var q1 = GLM_SQRT2 * qx;//q[1];
		var q2 = GLM_SQRT2 * qy;//q[2];
		var q3 = GLM_SQRT2 * qz;//q[3];
		var qda = q0 * q1;
		var qdb = q0 * q2;
		var qdc = q0 * q3;
		var qaa = q1 * q1;
		var qab = q1 * q2;
		var qac = q1 * q3;
		var qbb = q2 * q2;
		var qbc = q2 * q3;
		var qcc = q3 * q3;
		var m_0_0 = (1.0 - qbb - qcc);
		var m_0_1 = (qdc + qab);
		var m_0_2 = (-qdb + qac);
		var m_1_0 = (-qdc + qab);
		var m_1_1 = (1.0 - qaa - qcc);
		var m_1_2 = (qda + qbc);
		var m_2_0 = (qdb + qac);
		var m_2_1 = (-qda + qbc);
		var m_2_2 = (1.0 - qaa - qbb);
		// mat3_normalized_to_eul
		var eul1_0:Float, eul1_1:Float, eul1_2:Float;
		var eul2_0:Float, eul2_1:Float, eul2_2:Float;
		var cy = Math.sqrt(m_0_0*m_0_0+m_0_1*m_0_1);//hypotf
		if (cy > 16.0 * GLM_EPSILON) {
			eul1_0 = Math.atan2(m_1_2, m_2_2);
			eul1_1 = Math.atan2(-m_0_2, cy);
			eul1_2 = Math.atan2(m_0_1, m_0_0);
			eul2_0 = Math.atan2(-m_1_2, -m_2_2);
			eul2_1 = Math.atan2(-m_0_2, -cy);
			eul2_2 = Math.atan2(-m_0_1, -m_0_0);
		}
		else {
			eul1_0 = Math.atan2(-m_2_1, m_1_1);
			eul1_1 = Math.atan2(-m_0_2, cy);
			eul1_2 = 0.0;
			eul2_0 = eul1_0;
			eul2_1 = eul1_1;
			eul2_2 = eul1_2;
		}
		if (Math.abs(eul1_0) + Math.abs(eul1_1) + Math.abs(eul1_2) >
			Math.abs(eul2_0) + Math.abs(eul2_1) + Math.abs(eul2_2)) {
				return [eul2_0, eul2_1, eul2_2];
		}
		return [eul1_0, eul1_1, eul1_2];
	}
	static public function quat2eulerDeg(quat:Either<ArrayF,VectorF>):ArrayF {
		var euler = quat2euler(quat);
		euler[0] = euler[0]/Math.PI*180.0;
		euler[1] = euler[1]/Math.PI*180.0;
		euler[2] = euler[2]/Math.PI*180.0;
		return euler;
	}
	public static function quatDot(a:VectorF, b:VectorF):Float {
		return a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3];
	}
	public static function quatLength(q:VectorF):Float {
		var len_sq = quatDot(q,q); // q[0]*q[0] + q[1]*q[1] + q[2]*q[2] + q[3]*q[3];
		return Math.sqrt(len_sq);
	}
	public static function quatNormalize(q:VectorF, dest:VectorF):VectorF {
		var length:Float = quatLength(q);
		var mult:Float = 0;
		if(length >= GLM_EPSILON) {
			mult = 1 / length;
		}
		vec2vecScaled(q,mult,dest);
		return dest;
	}
	public static function quatSlerp(a:VectorF, b:VectorF, t:Float, dest:VectorF):VectorF {
		// calculate cosine
		var cosTheta:Float = quatDot(a, b);
		// if(shortWay && cosTheta<0){
		// 	// https://discussions.unity.com/t/not-interpolate-quaternion-on-shortest-path/73960/3
		// 	vec2vecScaled(a,-1,dest);
		// 	return quatSlerp(dest,b,t,dest,false);
		// }
		var bx:Float = b[0], by:Float = b[1], bz:Float = b[2], bw:Float = b[3];
		var ax:Float = a[0], ay:Float = a[1], az:Float = a[2], aw:Float = a[3];
		// if cosTheta < 0, the interpolation will go the long way around
		// invert 
		if(cosTheta < 0) {
			cosTheta = -cosTheta;
			bx = -bx;
			by = -by;
			bz = -bz;
			bw = -bw;
		}

		// perform a linear interpolation when cosTheta is
		// close to 1 to avoid side effect of sin(angle)
		// becoming a zero denominator
		if(cosTheta > 1 - GLM_EPSILON) {
			vec2vecLerped(a,b,t,dest);
			return dest;
		}
		else {
			var angle:Float = Math.acos(cosTheta);
			var sa:Float = 1 / Math.sin(angle);
			var i:Float = Math.sin((1 - t) * angle);
			var j:Float = Math.sin(t * angle);

			dest[0] = (i * ax + j * bx) * sa;
			dest[1] = (i * ay + j * by) * sa;
			dest[2] = (i * az + j * bz) * sa;
			dest[3] = (i * aw + j * bw) * sa;
			return dest;
		}
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

	static public function dumpSprite(spr:DisplayObject, props:PFFNodeProps):PFFNodeProps {
		if(props == null){
			props = new PFFNodeProps();
		}
		props.visible = spr.visible;
		props.alpha_self = spr.alpha;
		props.x = spr.x;
		props.y = spr.y;
		props.pivotX = spr.pivotX;
		props.pivotY = spr.pivotY;
		props.scaleX = spr.scaleX;
		props.scaleY = spr.scaleY;
		props.rotation = spr.rotation;
		return props;
	}
	static public function undumpSprite(spr:DisplayObject, props:PFFNodeProps):Void {
		spr.visible = props.visible;
		spr.alpha = props.alpha_self;
		spr.x = props.x;
		spr.y = props.y;
		spr.pivotX = props.pivotX;
		spr.pivotY = props.pivotY;
		spr.scaleX = props.scaleX;
		spr.scaleY = props.scaleY;
		spr.rotation = props.rotation;
	}

	static public function undumpAnimSprite(spr:DisplayObject, state:PFFNodeState):Void {
		if(state.a_dirty > 0){
			// trace("undumpAnimSprite alpha", spr.name);
			spr.visible = state.props.visible;
			// spr.alpha = props.alpha_self*props.alpha_mask;
			spr.alpha = state.props.alpha_self;
			state.a_dirty = 0;
		}
		if(state.xy_dirty > 0){
			// trace("undumpAnimSprite xy", spr.name);
			spr.x = state.props.x;
			spr.y = state.props.y;
			// spr.pivotX = state.props.pivotX;
			// spr.pivotY = state.props.pivotY;
			state.xy_dirty = 0;
		}
		if(state.sxsy_dirty > 0){
			// trace("undumpAnimSprite sxsy", spr.name);
			spr.scaleX = state.props.scaleX;
			spr.scaleY = state.props.scaleY;
			state.sxsy_dirty = 0;
		}
		if(state.r_dirty > 0){
			// trace("undumpAnimSprite r", spr.name);
			spr.rotation = state.props.rotation;
			state.r_dirty = 0;
		}
	}

	static public function getHierarchyChain(spr:DisplayObjectContainer):Array<DisplayObjectContainer> {
		var result:Array<DisplayObjectContainer> = [];
		if(spr == null){
			return result;
		}
		result.push(spr);
		var pp:DisplayObjectContainer = spr.parent;
		while (pp != null){
			result.push(pp);
			pp = pp.parent;
		}
		return result;
	}

	public static function strLimit(limitedStr: String, len: Int = 100, fromLeft: Bool = true, trimMark: String = "...") : String {
		if (limitedStr == null) {
			return "";
		}
		if (limitedStr.length > len) {
			if (fromLeft) {
				limitedStr = limitedStr.substring(0, len) + trimMark;
			}else{
				limitedStr = trimMark + limitedStr.substring(limitedStr.length - len);
			}
		}
		return limitedStr;
	}

	public static function intSign(n : Float) : Int{
		if (n == 0.0){
			return 0;
		}else if (n < 0){
			return -1;
		}
		return 1;
	}

	public static function strIndexOfAny(str:String, searchForStrOrArray:ArrayS, lowercase:Bool = false) : Int {
		if(str == null || searchForStrOrArray == null){
			return -1;
		}
		var strt = str;
		if(lowercase){
			strt = strt.toLowerCase();
		}
		// if(Std.isOfType(searchForStrOrArray, String)){
		// 	var searchf:String = searchForStrOrArray;
		// 	if(lowercase){
		// 		searchf = searchf.toLowerCase();
		// 	}
		// 	return strt.indexOf(searchf);
		// }
		var searchs:ArrayS = searchForStrOrArray;
		if(searchs == null){
			return -1;
		}
		for(i in 0...searchs.length){
			var searchf:String = searchs[i];
			if(lowercase){
				searchf = searchf.toLowerCase();
			}
			var iof = strt.indexOf(searchf);
			if(iof >= 0){
				return iof;
			}
		}
		return -1;
	}

	// result = index of first value greater than the target (target < values[result])
	// return -1/-2/-3 if: have no values, less than 2 value, target out of interval
	static public function binarySearch(values:Either<ArrayF,VectorF>, target:Float):Int {
		if(values == null){
			return -1;
		}
		var v_len = safeLen(values);
		if(v_len < 2){// At least TWO values needed
			return -1;
		}
		if(target < values[0]){
			return -2;
		}
		if(target >= values[v_len-1]){
			if(target > values[v_len-1]){
				return -3;
			}
			return v_len-1;
		}
		var low:Int = 0;
		var high:Int = v_len - 2;
		if (high == 0) return 1;
		var current:Int = high >>> 1;
		while (true) {
			if (values[current + 1] <= target){
				low = current + 1;
			}else{
				high = current;
			}
			if (low == high) return low + 1;
			current = (low + high) >>> 1;
		}
		return -1; // Never
	}

	static public function strIsEqual(str1:String, str2:String, ignoreCase:Bool = false, checkSpecialChars:Bool = false): Bool {
		if(str1 == null){
			str1="";
		}
		if(str2 == null){
			str2="";
		}
		if(ignoreCase){
			str1 = str1.toLowerCase();
			str2 = str2.toLowerCase();
		}
		if(str1 == str2){
			return true;
		}
		if(checkSpecialChars && str1.length > 0){
			if(str1 == "*" && str2.length > 0){
				return true;
			}
			if(str1.charAt(0) == "*" && StringTools.endsWith(str2, str1.substr(1))){
				return true;
			}
			if(str1.charAt(str1.length-1) == "*" && StringTools.startsWith(str2, str1.substr(0, str1.length-1))){
				return true;
			}
		}
		return false;
	}
}