package pff.starling;

import gltf.*;
import pff.starling.PFFAnimManager.PFFNodeProps;
import pff.starling.PFFAnimManager.PFFAnimNode;
import pff.starling.PFFAnimManager.PFFAnimState;
import haxe.io.Bytes;
import haxe.crypto.Base64;
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
* CONVENTIONS:
* gLTF and all required resources are expected to be present in gLTF (base64, binary chunks) or already loaded (as Starling assets, for example)
* gLTF can be parsed for external files list in advance - so they can be loaded before scene creation
* Conversions: Blender meters to starling pixels use kMeters3D_to_Pixels2D_ratio
* PFFScene expects Starling Texture for image resource by default - but any Texture-derived class should be fine. 
* - Caller may provide Texture taken from some atlas, for example
* By default all nodes are visible after creation. This can be further altered with Compositions
**/

class PFFScene {
	public function new(){};

	public var gltf_struct: GLTF = null;
	// first node with NO PARENTS
	public var gltf_root: DisplayObjectContainer = null;
	// Plain list of Starling objects (same order as gLTF nodes order)
	public var nodes_list: Array<PFFAnimNode> = null;
	// Plain list of Animation states (same order as gLTF animations order)
	public var animstates_list: Array<PFFAnimState> = null;
	// Blender`s custom props from scene root node
	// Caller may overload some fields before loading gltf (to customize node creation, etc)
	public var nodes_rootprops: Utils.MapS2A = new Utils.MapS2A();
	// Visibility-switch rules per composition
	public var nodes_compositions: Utils.MapS2A = new Utils.MapS2A();

	public var gltf_load_verbose: Bool = false;
	public var gltf_load_warnings: Utils.ArrayS = null;
	// Blindness conversion between gLTF translations/locations and pixels
	public var kPixels2D_to_Meters3D_ratio = 0.01;
	public var kMeters3D_to_Pixels2D_ratio = 1.0/0.01;
	public var kMetersXYZ_to_PixelsXY:Utils.ArrayI = [0,2];// px_x = loc[0], px_y = loc[2]
	public var kMetersXYZ_freeAxis = -1;// 2D-Rotation axis, Self-alpha axis on Scale, depends on kMetersXYZ_to_PixelsXY
	public var kPffMask_nodename = "#pff:mask";// Name of the node interpreted as a mask. Can be "#pff:mask.001" (Blender specifics) as well, etc
	var tmp_vec = new Utils.VectorF(3);

	/** 
	* Create all nodes and construct display list hierarchy. Assign gltf_root to root node of glft scene
	* gltf_resource_name: glft-file key in gltf_resources
	* gltf_resources: all resources required for glft loading. key: <file name>, value: starling.AssetManager.getAsset(<asset for key>)
	* returns gltf_root:DisplayObjectContainer (if no errors) or null.
	* In case of errors/warnings: gltf_load_warnings should contain explanations
	* In case of problems scene creation process should continue with best-effort fallbacks (is possible)
	**/
	public function makeSceneTree(gltf_resource_name:String, gltf_resources:Map<String,Dynamic>): DisplayObjectContainer
	{
		gltf_struct = null;
		gltf_root = null;// no unchild if != null, caller may use it further
		nodes_list = null;
		// nodes_rootprops - no change, can be used to drive custom node creations
		nodes_compositions = new Utils.MapS2A();
		gltf_load_warnings = null;
		function resource_by_uri(index: Int, uri: String): Bytes {
			if(Utils.safeLen(uri) > 0){
				var resource:Bytes = extractResourceWithExpectedType(this, uri, gltf_resources, 'uri_bin');
				if(resource != null){
					// log_i('buffer used: idx=${index}, uri=${Utils.strLimit(uri,150)}');
					return resource;
				}
			}
			log_e('error: gltf_resources[<buffer>] == null, Buffer: idx=${index}, uri=${Utils.strLimit(uri,150)}');
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
			log_i('GLTF parsing exception: ${e}');
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
			var trs_location_px = Utils.vec2vecScaled(nd.translation, kMeters3D_to_Pixels2D_ratio, tmp_vec).toArray();
			var trs_scale = Utils.vec2vecScaled(nd.scale,1.0, tmp_vec).toArray();
			var trs_rotation_eulerXYZ = Utils.quat2euler(nd.rotation);
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
									log_e('warning: texture not found, node: ${nd.name}, uri: ${Utils.strLimit(tex.image.uri,150)}');
								}
							}
						}
					}else{
						log_e('warning: mat not found, node: ${nd.name}');
					}
				}
				if(prim.attributes != null){
					// Positions. getting BBOX directly fomr min-max
					for(att in prim.attributes){
						if(att.name == "POSITION" && att.accessor != null){
							var bbox_min_px = Utils.vec2vecScaled(att.accessor.min, kMeters3D_to_Pixels2D_ratio, tmp_vec).toArray();
							var bbox_max_px = Utils.vec2vecScaled(att.accessor.max, kMeters3D_to_Pixels2D_ratio, tmp_vec).toArray();
							bbox_px = bbox_min_px.concat(bbox_max_px);
						}
					}
				}
			}
			var customprops = nd.extras;
			var starling_node = new PFFAnimNode();
			starling_node.full_path = nd.name;// Basic default, no hier
			starling_node.gltf_id = nd.id;
			starling_node.customprops = customprops;
			starling_node.z_order = trs_location_px[kMetersXYZ_freeAxis];
			// log_i('creating node: ${nd.name}, ${texture}, ${trs_location_px}, ${trs_scale}, ${trs_rotation_eulerXYZ}, ${bbox_px}, ${customprops}');
			if(nd.name.indexOf(kPffMask_nodename) >= 0){
				// Special case for kPffMask_nodename
				if(bbox_px != null){
					var spr_props:PFFNodeProps = prepareStarlingSpriteProps(trs_location_px, trs_scale, trs_rotation_eulerXYZ, bbox_px);
					var defl_quad = new starling.display.Quad(spr_props.bbox_w, spr_props.bbox_h);
					Utils.undumpSprite(defl_quad, spr_props);
					Utils.dumpSprite(defl_quad, starling_node);
					defl_quad.name = nd.name;
					starling_node.sprite = defl_quad;
				}
			}else{
				// fillStarlingNode can be overloaded - undumping initial sprite values from sprite itself
				fillStarlingNode(starling_node, nd.name, texture, trs_location_px, trs_scale, trs_rotation_eulerXYZ, bbox_px);
			}
			nodes_list.push(starling_node);
		}

		// Second pass - Setup hierarchy && detecti gltf_root
		// - gltf_root = first node with NO PARENTS
		for ( i in 0...(nodes_list.length) ){
			var starling_node = nodes_list[i];
			var node_sprite:DisplayObjectContainer = null;
			if(Std.isOfType(starling_node.sprite, DisplayObjectContainer)){
				node_sprite = cast(starling_node.sprite, DisplayObjectContainer);
			}
			var gltf_node = gltf_struct.nodes[i];// starling_node.gltf_id
			if(gltf_node.children != null && gltf_node.children.length > 0 && node_sprite != null){
				var child_order = gltf_node.children.toArray();
				// Sorting according to child node location Z-compinent
				// Critical for rendering order on the same hierarchy level
				child_order.sort( (nd1, nd2) -> {
					var  nd1_s = nodes_list[nd1.id];
					var  nd2_s = nodes_list[nd2.id];
					return Utils.intSign(nd1_s.z_order - nd2_s.z_order);
				} );
				for ( j in 0...(child_order.length) ){
					var child_id = child_order[j].id;
					// var child_starling_nodes = nodes_list.filter((nd) -> {return nd.gltf_id == child_id;} );
					// if(child_starling_nodes.length == 1){
					// var child_starling_node = child_starling_nodes[0];
					var child_starling_node = nodes_list[child_id];
					var child_gltf_node = gltf_struct.nodes[child_id];
					child_starling_node.gltf_parent_id = starling_node.gltf_id;
					if(child_gltf_node.name.indexOf(kPffMask_nodename) >= 0){
						// Special case: quad mask
						trace("- adding MASK", node_sprite, child_starling_node.sprite);
						if(child_starling_node.sprite != null){
							node_sprite.mask = child_starling_node.sprite;
						}
						continue;
					}
					var child_node_sprite:DisplayObjectContainer = null;
					if(Std.isOfType(child_starling_node.sprite, DisplayObjectContainer)){
						child_node_sprite = cast(child_starling_node.sprite, DisplayObjectContainer);
					}
					if(child_node_sprite == null){
						continue;
					}
					if(child_node_sprite.parent != null){
						log_e('warning: node parent not empty: ${child_node_sprite.name}');
					}
					node_sprite.addChild(child_node_sprite);
					// trace("- child", gltf_node.name, gltf_node.id, child_gltf_node.name, child_gltf_node.id);
					// }else{
					// 	log_e('warning: node child not found: ${gltf_node.name}: ${child_id}');
					// }
				}
			}
		}
		for ( i in 0...(nodes_list.length) ){
			var starling_node = nodes_list[i];
			var node_sprite:DisplayObjectContainer = null;
			if(Std.isOfType(starling_node.sprite, DisplayObjectContainer)){
				node_sprite = cast(starling_node.sprite, DisplayObjectContainer);
			}
			if(gltf_root == null && node_sprite != null && node_sprite.parent == null){
				// var gltf_node = gltf_struct.nodes[i];
				// log_i("- found root", gltf_node.id, gltf_node.name);
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
			if(node_sprite != null){
				var hierarchy = Utils.getHierarchyChain(node_sprite);
				var hierarchy_names = [ for (i in 0...(hierarchy.length) ) hierarchy[hierarchy.length-i-1].name ];
				starling_node.full_path = hierarchy_names.join("/");
			}
			log_i('Sprite: ${starling_node.full_path}, ${starling_node.toString()}');
		}
		animstates_list = [];
		if(gltf_struct.animations != null){
			for(i in 0...(gltf_struct.animations.length)){
				var nd = gltf_struct.animations[i];
				var anim_state:PFFAnimState = new PFFAnimState();
				anim_state.full_path = nd.name;
				anim_state.gltf_id = i;
				anim_state.gltfTimeMin = -1;
				anim_state.gltfTimeMax = -1;
				for(ch in nd.channels){
					for(smp in ch.samples){
						if(anim_state.gltfTimeMin < 0 || anim_state.gltfTimeMax < 0){
							anim_state.gltfTimeMin = smp.input;
							anim_state.gltfTimeMax = smp.input;
							continue;
						}
						anim_state.gltfTimeMin = Math.min(anim_state.gltfTimeMin,smp.input);
						anim_state.gltfTimeMax = Math.max(anim_state.gltfTimeMax,smp.input);
					}
				}
				trace("- loaded anim", anim_state.full_path, anim_state.gltfTimeMin, anim_state.gltfTimeMax);
				animstates_list.push(anim_state);
			}
		}
		if(gltf_root == null){
			log_e("warning: scene root not found");
		}
		return gltf_root;
	}

	public static function extractResourceWithExpectedType(scene:PFFScene, gltf_resource_name:String, gltf_resources:Map<String,Dynamic>, load_mode:String):Dynamic {
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
			if (dat == null && Std.isOfType(gltf_resource_name, String)){
				// base64 encoding in uri
				var val:String = cast(gltf_resource_name, String);
				if(StringTools.startsWith(val,"data:") && val.indexOf("base64,") > 0){
					var val_split = val.split("base64,");
					return Base64.decode(val_split[1]);
				}
			}
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

	public function prepareStarlingSpriteProps(trs_location_px:Utils.ArrayF, trs_scale:Utils.ArrayF, trs_rotation_eulerXYZ:Utils.ArrayF, bbox_px:Utils.ArrayF):PFFNodeProps {
		var pos_x:Float = trs_location_px[kMetersXYZ_to_PixelsXY[0]];
		var pos_y:Float = trs_location_px[kMetersXYZ_to_PixelsXY[1]];
		var scale_x:Float = trs_scale[kMetersXYZ_to_PixelsXY[0]];
		var scale_y:Float = trs_scale[kMetersXYZ_to_PixelsXY[1]];
		var rotation:Float = -1 * trs_rotation_eulerXYZ[kMetersXYZ_freeAxis];
		var bbox_min_x:Float = 0;
		var bbox_min_y:Float = 0;
		var bbox_max_x:Float = 0;
		var bbox_max_y:Float = 0;
		if(bbox_px != null){
			bbox_min_x = bbox_px[kMetersXYZ_to_PixelsXY[0]];
			bbox_min_y = bbox_px[kMetersXYZ_to_PixelsXY[1]];
			bbox_max_x = bbox_px[kMetersXYZ_to_PixelsXY[0] + 3];
			bbox_max_y = bbox_px[kMetersXYZ_to_PixelsXY[1] + 3];
		}
		var spr_props:PFFNodeProps = new PFFNodeProps();
		spr_props.visible = true;
		spr_props.alpha_self = trs_scale[kMetersXYZ_freeAxis];
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

	/**
	* Starling node generator. Can be overloaded to customazi starling sprite creation process
	* For example it is useful to place actual button in place of some default starling Quad/Sprite node
	**/
	public function fillStarlingNode(starling_node:PFFAnimNode, node_name:String, node_texture:Texture, trs_location_px:Utils.ArrayF, trs_scale:Utils.ArrayF, trs_rotation_eulerXYZ:Utils.ArrayF, bbox_px:Utils.ArrayF):Bool {
		var spr_props:PFFNodeProps = prepareStarlingSpriteProps(trs_location_px, trs_scale, trs_rotation_eulerXYZ, bbox_px);
		var defl_spr = new starling.display.Sprite();
		if(bbox_px != null){
			// Quad
			var defl_quad = new starling.display.Quad(spr_props.bbox_w, spr_props.bbox_h);
			if(node_texture != null){
				defl_quad.texture = node_texture;
			}
			defl_spr.addChild(defl_quad);
		}else{
			spr_props.pivotX = 0;
			spr_props.pivotY = 0;
		}
		defl_spr.touchable = false;
		Utils.undumpSprite(defl_spr, spr_props);
		// trace("Sprite init", node_name, spr_props.toString());
		Utils.dumpSprite(defl_spr, starling_node);
		defl_spr.name = node_name;
		starling_node.sprite = defl_spr;
		return true;
	}

	/**
	* Inspect gLTF/glb file and list all external resources required for preloading
	* gltf_resource_name: glft-file key in gltf_resources
	* gltf_resources: glft/glb file must be present
	**/
	public static function extractExternalResources(gltf_resource_name:String, gltf_resources:Utils.MapS2A):Utils.ArrayS
	{
		if(Utils.safeLen(gltf_resource_name) == 0 || Utils.safeLen(gltf_resources) == 0){
			log('extractExternalResources: invalid input: ${gltf_resource_name}');
			return null;
		}
		if(Utils.safeLen(gltf_resources[gltf_resource_name]) == 0){
			log('extractExternalResources: empty input: ${gltf_resource_name}');
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
						if(StringTools.startsWith(val,"data:")){
							// base64, not needed
							continue;
						}
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
	* Store composition visibility rules (according to show_set/hide_set) for future use
	* show_set/hide_set contain strings that checked against each node full_path in form "root-name/child-name/.../node-name"
	* show_set/hide_set may contain "*" string to match ALL nodes
	**/
	public function addComposition(composition_name:String, show_set:Utils.ArrayS, hide_set:Utils.ArrayS):Void
	{
		var spr_on:Array<PFFAnimNode> = filterNodesByPath(show_set, true);
		var spr_off:Array<PFFAnimNode> = filterNodesByPath(hide_set, true);
		nodes_compositions[composition_name] = [spr_on, spr_off];
		return;
	}

	/**
	* Alter nodes visibility according to composition
	**/
	public function activateComposition(composition_name:String):Bool
	{
		var vis_rules:Utils.ArrayA = nodes_compositions[composition_name];
		if(vis_rules == null){
			return false;
		}
		var spr_on:Array<PFFAnimNode> = vis_rules[0];
		var spr_off:Array<PFFAnimNode> = vis_rules[1];
		log_i('activating composition: ${composition_name}');
		makeCompositionActive(composition_name, spr_on, spr_off);
		return true;
	}

	/**
	* Can be overloaded to implement separate visibility change logic (fades/effect/etc)
	**/
	public function makeCompositionActive(composition_name:String, spritesToEnable:Array<PFFAnimNode>, spritesToDisable:Array<PFFAnimNode>):Void {
		if(spritesToDisable != null){
			for(spr in spritesToDisable){
				if(spr.sprite != null){
					spr.sprite.visible = false;
				}
				spr.visible = false;
				spr.a_dirty++;
			}
		}
		if(spritesToEnable != null){
			for(spr in spritesToEnable){
				if(spr.sprite != null){
					spr.sprite.visible = true;
				}
				spr.visible = true;
				spr.a_dirty++;
			}
		}
	}

	public function filterNodesByPath(full_paths:Utils.ArrayS, fuzzy_search:Bool = false):Array<PFFAnimNode> {
		var res:Array<PFFAnimNode> = [];
		if(Utils.safeLen(full_paths) == 0){
			return res;
		}
		for(nd in nodes_list){
			for(fp in full_paths){
				if(fp == "*"){
					res.push(nd);
				}else if(nd.full_path == fp){
					res.push(nd);
				} if(fuzzy_search && nd.full_path.indexOf(fp) >= 0){
					res.push(nd);
				}
			}
		}
		return res;
	}

	// ===============
	public function log_i(message:String) {
		if(!gltf_load_verbose){
			return;
		}
		log(message);
	}
	public function log_e(message:String) {
		if(gltf_load_warnings == null){
			gltf_load_warnings = new Array<String>();
		}
		gltf_load_warnings.push(message);
		log(message);
	}
	private static function log(str:String) {
		trace("PFFScene: ", str);
	}

	// ===============
	public function filterAnimsByName(full_paths:Utils.ArrayS, fuzzy_search:Bool = false):Array<PFFAnimState> {
		var res:Array<PFFAnimState> = [];
		if(Utils.safeLen(full_paths) == 0 || gltf_struct == null || gltf_struct.animations == null){
			return res;
		}
		for(nd in animstates_list){
			for(fp in full_paths){
				if(fp == "*"){
					res.push(nd);
				}else if(nd.full_path == fp){
					res.push(nd);
				} if(fuzzy_search && nd.full_path.indexOf(fp) >= 0){
					res.push(nd);
				}
			}
		}
		return res;
	}

	/**
	* Animations are applied in order using "influence" to node props first
	* Then all affected nodes+props are applied to real sratling sprites
	* anims: animations to apply, like "NLA Stack". Can be queried by filterAnimsByName
	* gltfTime: Blender-time to sample animation data
	**/
	public function applyAnimations(anims:Array<PFFAnimState>, gltfTime:Float): Bool {
		// try{
		var affectedNodes:Map<Int,PFFAnimNode> = new Map<Int,PFFAnimNode>();// Map with jey uniqness
		for(anim in anims){
			anim.gltfTime = gltfTime;
			if(anim.infl < Utils.GLM_EPSILON){
				continue;
			}
			var nd = gltf_struct.animations[anim.gltf_id];
			var t = 0.0;
			var td = 0.0;
			for(ch in nd.channels){
				// Looking gltfTime in ch.timestamps
				var intrp:String = ch.interpolation;
				var smp = ch.samples;
				var ch_idx = Utils.binarySearch(ch.timestamps, gltfTime);// ch_idx: ch.timestamps[ch_idx] > gltfTime
				if(ch_idx == -1){
					// If less that 2 timestamps - nothing to interpolate
					continue;
				}
				if(ch_idx == -2){
					// Sticking to start
					ch_idx = 1;
					gltfTime = ch.timestamps[ch_idx-1];
				}else if(ch_idx == -3){
					// Sticking to end
					ch_idx = ch.timestamps.length-1;
					gltfTime = ch.timestamps[ch_idx];
				}
				td = (ch.timestamps[ch_idx]-ch.timestamps[ch_idx-1]);
				t = (gltfTime-ch.timestamps[ch_idx-1])/td;
				if(intrp == "LINEAR" && ch.path == "rotation"){
					intrp = "SLERP";
				}
				// trace("- interpolating", anim.full_path, intrp, gltfTime, ch_idx, t);// haxe.Json.stringify(ch.timestamps)
				// Getting interpolated vector
				var val_at_t:Utils.VectorF = smp[ch_idx-1].output.copy();//  "STEP"
				if(intrp == "LINEAR"){
					var val_at_t2 = smp[ch_idx].output;
					Utils.vec2vecLerped(val_at_t, val_at_t2, t, val_at_t);
				}
				if(intrp == "SLERP"){
					// When targeting a rotation, spherical linear interpolation (slerp) should be used to interpolate quaternions.
					Utils.quatSlerp(smp[ch_idx-1].output, smp[ch_idx].output, t, val_at_t);
				}
				if(intrp == "CUBICSPLINE"){
					// The number of output elements must equal three times the number of input elements.
					// https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#_overview_2
					var vk0 = smp[ch_idx-1].output;
					var bk0 = smp[ch_idx-1].output_out;
					var ak1 = smp[ch_idx].output_in;
					var vk1 = smp[ch_idx].output;
					val_at_t = vk0.copy();
					var t2 = t*t;
					var t3 = t2*t;
					// trace("- CUBICSPLINE", vk0, vk1, val_at_t, val_at_t.length);
					for(vi in 0...val_at_t.length){
						val_at_t[vi] = (2.0*t3-3.0*t2+1)*vk0[vi]
							+td*(t3-2*t2+t)*bk0[vi]
							+(-2.0*t3+3.0*t2)*vk1[vi]
							+td*(t3-t2)*ak1[vi];
					}
				}
				var cn_node = nodes_list[ch.node.id];
				affectedNodes[cn_node.gltf_id] = cn_node;
				if(ch.path == "translation"){
					var trs_location_px = Utils.vec2vecScaled(val_at_t, kMeters3D_to_Pixels2D_ratio, tmp_vec);
					var trs_x = trs_location_px[kMetersXYZ_to_PixelsXY[0]];
					var trs_y = trs_location_px[kMetersXYZ_to_PixelsXY[1]];
					if(anim.infl < 1.0){
						cn_node.x = Utils.f2fLerped(cn_node.x,trs_x,anim.infl);
						cn_node.y = Utils.f2fLerped(cn_node.y,trs_y,anim.infl);
					}else{
						cn_node.x = trs_x;
						cn_node.y = trs_y;
					}
					cn_node.xy_dirty++;
				}
				if(ch.path == "rotation"){
					Utils.quatNormalize(val_at_t, val_at_t);
					var trs_rotation_eulerXYZ = Utils.quat2euler(val_at_t);
					var rotation:Float = -1 * trs_rotation_eulerXYZ[kMetersXYZ_freeAxis];
					if(anim.infl < 1.0){
						cn_node.rotation = Utils.f2fLerped(cn_node.rotation,rotation,anim.infl);
					}else{
						cn_node.rotation = rotation;
					}
					cn_node.r_dirty++;
				}
				if(ch.path == "scale"){
					var trs_scale = Utils.vec2vecScaled(val_at_t, 1.0, tmp_vec);
					var trs_sx = trs_scale[kMetersXYZ_to_PixelsXY[0]];
					var trs_sy = trs_scale[kMetersXYZ_to_PixelsXY[1]];
					if(anim.infl < 1.0){
						cn_node.scaleX = Utils.f2fLerped(cn_node.scaleX,trs_sx,anim.infl);
						cn_node.scaleY = Utils.f2fLerped(cn_node.scaleY,trs_sx,anim.infl);
					}else{
						cn_node.scaleX = trs_sx;
						cn_node.scaleY = trs_sy;
					}
					cn_node.sxsy_dirty++;
					var alpha_self = trs_scale[kMetersXYZ_freeAxis];
					if(alpha_self != cn_node.alpha_self){
						if(anim.infl < 1.0){
							cn_node.alpha_self = Utils.f2fLerped(cn_node.alpha_self,alpha_self,anim.infl);
						}else{
							cn_node.alpha_self = alpha_self;
						}
						cn_node.a_dirty++;
					}
				}
			}
		}
		// Iterating over map calues
		for(anim_nd in affectedNodes){
			if(anim_nd.sprite == null){
				continue;
			}
			Utils.undumpAnimSprite(anim_nd.sprite,anim_nd);
		}
		// }catch (e : Any) {
		// 	trace('Anim exception: ${e}');
		// }
		return true;
	}
}