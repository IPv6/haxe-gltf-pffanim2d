package starling.gltf;

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
}