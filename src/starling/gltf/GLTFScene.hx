package starling.gltf;


import gltf.*;
import haxe.io.Bytes;
import openfl.utils.ByteArray;
import starling.core.Starling;
import starling.textures.Texture;
import starling.events.*;
import starling.display.Sprite;
import starling.display.Image;
import starling.display.Stage;
import starling.display.DisplayObject;
import starling.display.DisplayObjectContainer;

/**

# CONVENTIONS:
- gLTF and all resources requered are expected to be present in gLTF (base64, binary chunks) or already loaded (as Starling assets, for example)
- gLTF can be parsed for external files list in advance - so they can be loaded before scene creation
- Blender meters to starling pixels use kMeters3D_to_Pixels2D_ratio

- By default all nodes are visible after creation. This can be further altered with Compositions

# Compositions:
- Named after same feature of Krita
- Each composition - simple ruleset (on/off) for nodes visibility
// So it`s possible to create all interfaces in one hierarchy and on/off bunch of layers to "switch" between them

# Blender to Starling essentials:
- Cameras, Armatures, skinning, morth tarkets, shapekeys - ignored
- Valid blender objects: Empties for grouping, simple quads (4-vert rectangle) mesh objects
// Quads imported as display.DisplayObjectContainer and display.Image
// All other nodes in gLTF are ignored
- Quads must have unlit textures, they will used for display.Image content for node
- Quads must be in Blender XY-plane (for top-down view)
- Animations: Armature animations are not supported directly, must be baked on valid objects to be usable by GLTFScene
- Animations: Actions must be stashed (Dopesheet-Action Editor) or pushed to NLA track (NLA Editor)
// Export name will be the name of action in any case
- Animations: Actions must always have frame 0 keyed (exporter resets any offset)

**/

class GLTFScene {
	public function new(){};

	public var gltf_struct:GLTF;
	public var gltf_root: DisplayObjectContainer;
	public var gltf_load_warnings: Array<String>;
	public var kMeters3D_to_Pixels2D_ratio = 0.01;

	/** 
	* Create all nodes and construct display list hierarchy. Assign gltf_root to root node of glft scene
	* @param gltf_resource_name: glft-file key in gltf_resources
	* @param gltf_resources: all resources required for glft loading. key: <file name>, value: starling.AssetManager.getAsset(<asset for key>)
	* @param gltf_node_generators: custom node generators-functions. Useful to place actual button in place of some node - instead of default display.Image with button texture
	* @return True if no errors. In case of errors/warnings gltf_load_warnings will be filled with explanations
	* In case of error scene creation will continue (on best-effort fallbacks possible)
	**/
	public function createSceneTree(gltf_resource_name:String, gltf_resources:Map<String,Dynamic>, gltf_node_generators:Map<String,Dynamic>): DisplayObjectContainer
	{
		gltf_load_warnings = new Array<String>();
		function log_e(message:String) {
			gltf_load_warnings.push(message);
			log(message);
		}
		function resource_by_uri(index: Int, uri: String): Bytes {
			if(Utils.safeLen(uri) > 0){
				// TBD: base64 encoding in uri
				var dat = gltf_resources[uri];
				// if (Std.is(data, String))
				// if (Std.is(data, Bytes)) {
				// if (Std.is(data, ByteArrayData))
				var byteArray:ByteArray = cast(dat, ByteArray);
				if(byteArray != null){
					log("buffer used: idx="+index+", uri="+uri);
					// log_e("// buffer getter: unexpected type: " + Type.typeof(dat));
					// return Bytes.ofData(dat);
					byteArray.position = 0;
					var bytes:Bytes = Bytes.alloc(byteArray.length);
					while (byteArray.bytesAvailable > 0) {
						bytes.set(byteArray.position, byteArray.readByte());
					}
					return bytes;
				}
			}
			log_e("error: gltf_resources[<buffer>] == null, Buffer: idx="+index+", uri="+uri);
			return Bytes.alloc(0);
		};
		if(Utils.safeLen(gltf_resource_name) == 0 || Utils.safeLen(gltf_resources) == 0){
			log_e("error: !gltf_resource_name || !gltf_resources");
			return null;
		}
		if(Utils.safeLen(gltf_resources[gltf_resource_name]) == 0){
			log_e("error: gltf_resources[gltf_resource_name] == null");
			return null;
		}
		// try {
			var json_raw = gltf_resources[gltf_resource_name];
			if(Std.isOfType(json_raw,String)){
				gltf_struct = GLTF.parseAndLoadWithBuffer(json_raw, resource_by_uri);
			}else if(Type.typeof(json_raw) == Type.ValueType.TObject ){
				// Can be object parsed by Starling, converting to JSON string...
				var json_str = haxe.Json.stringify(json_raw);
				gltf_struct = GLTF.parseAndLoadWithBuffer(json_str, resource_by_uri);
			}else{
				// ByteArray
				// TBD: parseAndLoadGLB for glb files
				log_e("error: glb not supported yet");
			}
		// }catch (e : Any) {
		// 	trace("GLTF parsing exception", e);
		// 	log_e("exception: GLTF parsing failed");
		// 	return null;
		// }

		// First pass - Creating all nodes separately

		// Second pass - Setup hierarchy
		return gltf_root;
	}

	/**
	* Inspect gLTF/glb file and list all external resources required for preloading
	* @param gltf_resource_name: glft-file key in gltf_resources
	* @param gltf_resources: glft/glb file must be present
	**/
	public static function extractExternalResources(gltf_resource_name:String, gltf_resources:Utils.MapS2A):Utils.ArrayS
	{
		if(Utils.safeLen(gltf_resource_name) == 0 || Utils.safeLen(gltf_resources) == 0){
			log("extractExternalResources: invalid input");
			return null;
		}
		if(Utils.safeLen(gltf_resources[gltf_resource_name]) == 0){
			log("extractExternalResources: invalid input");
			return null;
		}
		var json_raw = gltf_resources[gltf_resource_name];
		var json_str:String = "";
		if(Std.isOfType(json_raw,String)){
			json_str = json_raw;
		}else if(Type.typeof(json_raw) == Type.ValueType.TObject ){
			// Can be object parsed by Starling, converting to JSON string...
			json_str = haxe.Json.stringify(json_raw);
		}else{
			// ByteArray
			// TBD: parseAndLoadGLB for glb files
			log("extractExternalResources: glb not supported yet");
			return null;
		}
		var externals_map:Utils.ArrayS = [];
		var gltf_content:haxe.DynamicAccess<Dynamic> = null;
		try {
			gltf_content = haxe.Json.parse(json_str);
			function enumFields(dynobj:haxe.DynamicAccess<Dynamic>):Void {
				for (key in dynobj.keys()){
					var val = dynobj.get(key);
					// trace("- ", key, val, Type.typeof(val));
					if(key == "uri" && Std.isOfType(val, String)){
						if(externals_map.indexOf(val) < 0){
							externals_map.push(val);
						}
						continue;
					}
					if( Std.isOfType(val, Array) ){ // Std.isOfType(val, List) ||
						for(val2 in cast(val, Array<Dynamic>)){
							if(Type.typeof(val2) == Type.ValueType.TObject ){
								// trace("- > ARR", key);
								enumFields(val2);
							}
						}
					}
					if(Type.typeof(val) == Type.ValueType.TObject ){ // Std.isOfType(val, List) ||
						// trace("- > OBJ", key);
						enumFields(val);
					}
				}
			}
			enumFields(gltf_content);
		} catch (e : Any) {
			log("extractExternalResources: invalid json");
			return null;
		}
		return externals_map;
	}

	/**
	* Store composition visibility rules (according to visible_set/hidden_set) for future use
	* visible_set/hidden_set contain strings that checked against each node full path in form "root-name/child-name/.../node-name"
	* visible_set/hidden_set may contain "*" string, which matches all nodes
	**/
	public function addComposition(composition_name:String, visible_set:Utils.ArrayS, hidden_set:Utils.ArrayS):Void
	{
		return;
	}

	/**
	* * Alter nodes visibility according to composition
	**/
	public function activateComposition(composition_name):Bool
	{
		return true;
	}

	private static function log(str:String) {
		trace("GLTFScene: ", str);
	}
}