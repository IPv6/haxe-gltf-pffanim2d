package starling.gltf;


import sys.net.UdpSocket;
import gltf.*;
import haxe.io.Bytes;
import openfl.utils.ByteArray;
import starling.core.Starling;
import starling.events.*;
import starling.display.Sprite;
import starling.display.Image;
import starling.display.Quad;
import starling.display.Stage;
import starling.display.DisplayObject;
import starling.display.DisplayObjectContainer;
import starling.textures.Texture;

/**

# CONVENTIONS:
- gLTF and all required resources are expected to be present in gLTF (base64, binary chunks) or already loaded (as Starling assets, for example)
- gLTF can be parsed for external files list in advance - so they can be loaded before scene creation
- Conversions: Blender meters to starling pixels use kMeters3D_to_Pixels2D_ratio
- GLTFScene expects Starling Texture for image resource by default - but any Texture-derived class should be fine. 
// Caller may provide Texture taken from some atlas, for example
- By default all nodes are visible after creation. This can be further altered with Compositions

**/

class GLTFScene {
	public function new(){};

	public var gltf_struct: GLTF = null;
	// first node with NO PARENTS
	public var gltf_root: DisplayObjectContainer = null;
	// Plain list of Starling objects (same order as gLTF nodes)
	public var nodes_list: Array<PFFAnimNode> = null;
	// Blender`s custom props from scene root node. Caller may overload some field before loading gltf
	// can be used to drive custom node creations
	public var nodes_rootprops: Utils.MapS2A = new Utils.MapS2A();

	public var gltf_load_warnings: Utils.ArrayS = null;
	// Blindness conversion between gLTF translations/locations and pixels
	public var kPixels2D_to_Meters3D_ratio = 0.01;
	public var kMeters3D_to_Pixels2D_ratio = 1.0/0.01;
	public var kMetersXYZ_to_PixelsXY:Utils.ArrayI = [0,2];// px_x = loc[0], px_y = loc[2]
	public var kMetersXYZ_freeAxis = -1;// 2D-Rotation axis, Self-alpha axis on Scale

	/** 
	* Create all nodes and construct display list hierarchy. Assign gltf_root to root node of glft scene
	* @param gltf_resource_name: glft-file key in gltf_resources
	* @param gltf_resources: all resources required for glft loading. key: <file name>, value: starling.AssetManager.getAsset(<asset for key>)
	* @param gltf_node_generator: custom node generators-functions. For example it is useful to place actual button in place of some default starling Quad/Sprite node
	* @return root DisplayObject if no errors or null.
	* In case of errors/warnings gltf_load_warnings will be filled with explanations
	* In case of scene creation problems process will continue with best-effort fallbacks, is possible
	**/
	public function createSceneTree(gltf_resource_name:String, gltf_resources:Map<String,Dynamic>, 
		gltf_node_generator:(GLTFScene, String, Texture, Utils.ArrayF, Utils.ArrayF, Utils.ArrayF, Utils.ArrayF, Dynamic)->DisplayObjectContainer): DisplayObjectContainer
	{
		gltf_struct = null;
		gltf_root = null;// no unchild if != null, caller may use it further
		nodes_list = null;
		// nodes_rootprops - no change, can be used to drive custom node creations
		gltf_load_warnings = new Array<String>();
		if(gltf_node_generator == null){
			gltf_node_generator = defaultStarlingSpriteGenerator;
		}
		function log_e(message:String) {
			gltf_load_warnings.push(message);
			log(message);
		}
		function resource_by_uri(index: Int, uri: String): Bytes {
			if(Utils.safeLen(uri) > 0){
				var resource:Bytes = extractResourceWithExpectedType(this, uri, gltf_resources, 'uri_bin');
				if(resource != null){
					log("buffer used: idx="+index+", uri="+uri);
					return resource;
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
		try {
			var json_str:String = extractResourceWithExpectedType(this, gltf_resource_name, gltf_resources, 'gltf_json');
			if(Utils.safeLen(json_str) == 0){
				log_e("error: gltf json not found");
				return null;
			}
			gltf_struct = GLTF.parseAndLoadWithBuffer(json_str, resource_by_uri);
		}catch (e : Any) {
			trace("GLTF parsing exception", e);
			log_e("error: GLTF parsing exception");
		}
		if(gltf_struct == null){
			log_e("error: GLTF == null");
			return null;
		}
		// detecting kMetersXYZ_freeAxis
		var xyz_avail = [0,1,2].filter( (val) -> { return kMetersXYZ_to_PixelsXY.indexOf(val) < 0; } );
		if(xyz_avail.length != 1){
			log_e("error: invalid kMetersXYZ_to_PixelsXY");
			return null;
		}
		kMetersXYZ_freeAxis = xyz_avail[0];
		// First pass - Creating all nodes separately
		nodes_list = [];
		for(nd in gltf_struct.nodes){
			var name = nd.name;
			var trs_location_px = Utils.xyz2xyzScaled(nd.translation, kMeters3D_to_Pixels2D_ratio);
			var trs_scale = Utils.xyz2xyzScaled(nd.scale);
			var trs_rotation_eulerXYZ = Utils.quaternion2euler(nd.rotation);
			var bbox_px:Utils.ArrayF = null;
			var texture:Texture = null;
			if(nd.mesh != null && Utils.safeLen(nd.mesh.primitives) > 0){
				var prim = nd.mesh.primitives[0];
				if(prim.material != null){
					var mat_id = prim.material;
					var mat = gltf_struct.material[mat_id];
					if(mat != null && mat.pbrMetallicRoughness != null){
						var pbr = mat.pbrMetallicRoughness;
						if(pbr != null && pbr.baseColorTexture != null){
							var tex_id = pbr.baseColorTexture.index;
							var tex = gltf_struct.textures[tex_id];
							if(tex != null && tex.image != null){
								var dat = extractResourceWithExpectedType(this, tex.image.uri, gltf_resources, 'uri_tex');
								texture = cast(dat, Texture);
								if(texture == null){
									log_e("warning: texture not found, node: "+nd.name+", uri: "+tex.image.uri);
								}
							}
						}
					}else{
						log_e("warning: mat not found, node: "+nd.name);
					}
				}
				if(prim.attributes != null){
					// Positions. getting BBOX directly fomr min-max
					for(att in prim.attributes){
						if(att.name == "POSITION" && att.accessor != null){
							var bbox_min_px = Utils.xyz2xyzScaled(att.accessor.min, kMeters3D_to_Pixels2D_ratio);
							var bbox_max_px = Utils.xyz2xyzScaled(att.accessor.max, kMeters3D_to_Pixels2D_ratio);
							bbox_px = bbox_min_px.concat(bbox_max_px);
						}
					}
				}
			}
			var customprops = nd.extras;
			// trace("- creating node", nd.name, texture, trs_location_px, trs_scale, trs_rotation_eulerXYZ, bbox_px, customprops);
			var node_sprite:DisplayObjectContainer = gltf_node_generator(this, nd.name, texture, trs_location_px, trs_scale, trs_rotation_eulerXYZ, bbox_px, customprops);
			if(node_sprite == null){
				node_sprite = new starling.display.Sprite();
			}
			var starling_node = new PFFAnimNode();
			node_sprite.name = nd.name;
			starling_node.gltf_id = nd.id;
			starling_node.sprite = node_sprite;
			starling_node.customprops = customprops;
			Utils.dumpSprite(node_sprite, starling_node);
			nodes_list.push(starling_node);
		}

		// Second pass - Setup hierarchy && detecti gltf_root
		// - gltf_root = first node with NO PARENTS
		for ( i in 0...(nodes_list.length) ){
			var starling_node = nodes_list[i];
			var node_sprite = starling_node.sprite;
			var gltf_node = gltf_struct.nodes[i];
			if(gltf_node.children!=null && gltf_node.children.length > 0){
				for ( j in 0...(gltf_node.children.length) ){
					var child_id = gltf_node.children[j].id;
					var child_starling_node = nodes_list[child_id];
					var child_node_sprite = child_starling_node.sprite;
					if(child_node_sprite.parent != null){
						log_e("warning: node parent not empty: "+child_node_sprite.name);
					}
					child_starling_node.gltf_parent_id = starling_node.gltf_id;
					node_sprite.addChild(child_node_sprite);
					// trace("- child", gltf_node.name, gltf_node.id, child_gltf_node.name, child_gltf_node.id);
				}
			}
		}
		for ( i in 0...(nodes_list.length) ){
			var starling_node = nodes_list[i];
			var node_sprite = starling_node.sprite;
			if(gltf_root == null && node_sprite.parent == null){
				// var gltf_node = gltf_struct.nodes[i];
				// trace("- found root", gltf_node.id, gltf_node.name);
				gltf_root = node_sprite;
				if(starling_node.customprops != null){
					// Adding props to nodes_rootprops
					var dynobj:haxe.DynamicAccess<Dynamic> = starling_node.customprops;
					for (key in dynobj.keys()){
						if(nodes_rootprops[key] != null){
							// already filled, no overwrite
							continue;
						}
						var val = dynobj.get(key);
						nodes_rootprops[key] = val;
					}
				}
			}
			var hierarchy = Utils.getHierarchyChain(node_sprite);
			var hierarchy_names = [ for (i in 0...(hierarchy.length) ) hierarchy[hierarchy.length-i-1].name ];
			starling_node.full_path = hierarchy_names.join("/");
			// var spr_props = Utils.dumpSprite(starling_node, null);
			// trace("Sprite dump", starling_node.sprite.name, starling_node.full_path, starling_node.toString());
		}
		if(gltf_root == null){
			log_e("warning: scene root not found");
		}
		return gltf_root;
	}

	public static function extractResourceWithExpectedType(scene:GLTFScene, gltf_resource_name:String, gltf_resources:Map<String,Dynamic>, load_mode:String):Dynamic {
		if(load_mode == 'gltf_json'){
			var json_raw = gltf_resources[gltf_resource_name];
			var json_str:String = "";
			if(Std.isOfType(json_raw,String)){
				json_str = json_raw;
			}else if(Type.typeof(json_raw) == Type.ValueType.TObject ){
				// Can be object parsed by Starling, converting to JSON string...
				json_str = haxe.Json.stringify(json_raw);
			}else{
				// ByteArray? GLB?
				log("extractResourceWithExpectedType: glb not supported yet");
				return null;
			}
			return json_str;
		}
		if(load_mode == 'uri_bin'){
			var dat = gltf_resources[gltf_resource_name];
			// if (Std.is(data, String)) - TBD: base64 encoding in uri
			// if (Std.is(data, Bytes)) {
			// if (Std.is(data, ByteArrayData))
			var byteArray:ByteArray = cast(dat, ByteArray);
			if(byteArray != null){
				return Utils.openflByteArray2haxeBytes(byteArray);
			}
		}
		if(load_mode == 'uri_tex'){
			var dat = gltf_resources[gltf_resource_name];
			return dat;
		}
		return null;
	}

	public static function defaultStarlingSpriteProps(scene:GLTFScene, trs_location_px:Utils.ArrayF, trs_scale:Utils.ArrayF, trs_rotation_eulerXYZ:Utils.ArrayF, bbox_px:Utils.ArrayF):PFFAnimNode.PFFNodeProps {
		var pos_x:Float = trs_location_px[scene.kMetersXYZ_to_PixelsXY[0]];
		var pos_y:Float = trs_location_px[scene.kMetersXYZ_to_PixelsXY[1]];
		var scale_x:Float = trs_scale[scene.kMetersXYZ_to_PixelsXY[0]];
		var scale_y:Float = trs_scale[scene.kMetersXYZ_to_PixelsXY[1]];
		var rotation:Float = trs_rotation_eulerXYZ[scene.kMetersXYZ_freeAxis];
		var bbox_min_x:Float = 0;
		var bbox_min_y:Float = 0;
		var bbox_max_x:Float = 0;
		var bbox_max_y:Float = 0;
		if(bbox_px != null){
			bbox_min_x = bbox_px[scene.kMetersXYZ_to_PixelsXY[0]];
			bbox_min_y = bbox_px[scene.kMetersXYZ_to_PixelsXY[1]];
			bbox_max_x = bbox_px[scene.kMetersXYZ_to_PixelsXY[0] + 3];
			bbox_max_y = bbox_px[scene.kMetersXYZ_to_PixelsXY[1] + 3];
		}
		var spr_props:PFFAnimNode.PFFNodeProps = new PFFAnimNode.PFFNodeProps();
		spr_props.visible = true;
		spr_props.alpha_self = 1.0;
		spr_props.x = pos_x;
		spr_props.y = pos_y;
		spr_props.scaleX = scale_x;
		spr_props.scaleY = scale_y;
		spr_props.rotation = rotation;
		spr_props.bbox_w = bbox_max_x-bbox_min_x;
		spr_props.bbox_h = bbox_max_y-bbox_min_y;
		spr_props.pivotX = spr_props.bbox_w*0.5 - (bbox_min_x+bbox_max_x) * 0.5;
		spr_props.pivotY = spr_props.bbox_h*0.5 - (bbox_min_y+bbox_max_y) * 0.5;
		return spr_props;
	}

	public static function defaultStarlingSpriteGenerator(scene:GLTFScene, node_name:String, node_texture:Texture, trs_location_px:Utils.ArrayF, trs_scale:Utils.ArrayF, trs_rotation_eulerXYZ:Utils.ArrayF, bbox_px:Utils.ArrayF, customprops:Dynamic):DisplayObjectContainer {
		var spr_props:PFFAnimNode.PFFNodeProps = defaultStarlingSpriteProps(scene, trs_location_px, trs_scale, trs_rotation_eulerXYZ, bbox_px);
		var defl_spr = new starling.display.Sprite();
		if(node_texture != null){
			// Quad
			var defl_quad = new starling.display.Quad(spr_props.bbox_w, spr_props.bbox_h);
			defl_quad.texture = node_texture;
			defl_spr.addChild(defl_quad);
		}
		Utils.undumpSprite(defl_spr, spr_props);
		// trace("Sprite init", node_name, spr_props.toString());
		return defl_spr;
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

		var json_str:String = extractResourceWithExpectedType(null, gltf_resource_name, gltf_resources, 'gltf_json');
		if(Utils.safeLen(json_str) == 0){
			log("extractExternalResources: gltf json: not found");
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
	* visible_set/hidden_set contain strings that checked against each node full_path in form "root-name/child-name/.../node-name"
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