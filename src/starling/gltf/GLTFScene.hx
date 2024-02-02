package starling.gltf;


import gltf.*;
import haxe.io.Bytes;
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
		function llog(message:String) {
			gltf_load_warnings.push(message);
			log(message);
		}
		if(Utils.safeLen(gltf_resource_name) == 0 || Utils.safeLen(gltf_resources) == 0){
			llog("error: gltf_resource_name || gltf_resources");
			return null;
		}
		if(Utils.safeLen(gltf_resources[gltf_resource_name]) == 0){
			llog("error: gltf_resource_name, gltf_resource_name not found");
			return null;
		}
		var json = gltf_resources[gltf_resource_name];
		// TBD: parseAndLoadGLB for glb files
		gltf_struct = GLTF.parseAndLoadWithBuffer(json, function(index: Int, uri: String): Bytes {
			if(Utils.safeLen(uri) > 0){
				log("Buffer used: idx"+index+", uri"+uri);
				var dat = gltf_resources[uri];
				if(dat != null){
					return Bytes.ofData(dat);
				}
			}
			llog("error: gltf_resources, buffer not found (idx"+index+",uri"+uri+")");
			return Bytes.alloc(0);
		});
		
		return gltf_root;
	}

	/**
	* Inspect gLTF/glb file and list all external resources required for preloading
	* @param gltf_resource_name: glft-file key in gltf_resources
	* @param gltf_resources: glft/glb file must be present
	**/
	public static function extractExternalResources(gltf_resource_name:String, gltf_resources:Map<String,Dynamic>):Array<String>
	{
		if(Utils.safeLen(gltf_resource_name) == 0 || Utils.safeLen(gltf_resources) == 0){
			log("extractExternalResources: invalid input");
			return null;
		}
		if(Utils.safeLen(gltf_resources[gltf_resource_name]) == 0){
			log("extractExternalResources: invalid input");
			return null;
		}
		var externals_map:Array<String> = [];
		var gltf_content:haxe.DynamicAccess<Dynamic> = null;
		try {
			gltf_content = haxe.Json.parse(gltf_resources[gltf_resource_name]);
			function enumFields(dynobj:haxe.DynamicAccess<Dynamic>):Void {
				for (key in dynobj.keys()){
					var val = dynobj.get(key);
					// trace("- ", key, val, Type.typeof(val));
					if(key == "uri" && Std.isOfType(val, String)){
						externals_map.push(val);
						continue;
					}
					if( Std.isOfType(val, Array) ){ // Std.isOfType(val, List) ||
						for(val2 in cast(val,Array<Dynamic>)){
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
		}
		catch (e : Any) {
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
	public function addComposition(composition_name:String, visible_set:Array<String>, hidden_set:Array<String>):Void
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