# Simple 2d Animation Library
- Intended workflow: Blender -> gLTF -> OpenFL/Starling game
- Supported: Objects (empty/quad) TRS animations
- Somewhat supported: Alpha animation, Clipping rect animation (sprite masking) - see below

# Blender setup details

- Recognizable objects: Empties for grouping and simple planes (4-vert rectangle, quad) mesh objects for starling sprites
- Empties && Quads must be arranged in Blender XY-plane (for top-down view)
// All other nodes in gLTF are ignored
- Quads may have unlit textures - quad material image applied as Texture for corresponding starling node (by default)
- Plane(Quad) can have origin offset - offset converted to Sprite pivot (by default)
- Plane/Empty can have custom props - they are loaded and can be used for customizing starling node creation
- Animations: Armature animations are not supported directly - can be baked on valid objects before export
- Animations: Actions must be stashed (Dopesheet-Action Editor) or pushed to NLA track (NLA Editor)
// Export name will be the name of action in both cases
- Animations: Actions must always have frame 0 keyed
// Since exporter resets any timeline offset anyway
- Blender export options: TODO

# Alpha && Clipping animation conventions

gLTF does not support non-TRS animation targets. So some extra efforts required to make it happen with Blender && gLTF.
1) Basic alpha: derived from node's Scale Z (Blender z-axis), since it's not used for 2D scaling and defaults to 1.0. Named alpha_self in hx
2) Animated clipping: some Nodes are served as "placeholders" for holding such animations.
Each Empty (in Blender) can contain Plane (quad) Mesh object with the name "#pff:mask".
"#pff:mask" object will have special meaning for animation in Starling:
- Plane (Quad) rectangle = clipping rect for parent DisplayObjectContainer
- if ScaleX && ScaleY == 0.0 clipping mask ignored completely (on load, no realtime overhead), while alpha animation (alpha_mask) with ScaleZ still can be used
3) "#pff:mask" ScaleZ also can be used to animate alpha on enclosing container, this is named alpha_mask in hx
4) 


# Compositions:
- Compositions can be used to alter visibility of nodes en-masse. Named after same feature of Krita
// With compositions it is possible to create several interfaces in one hierarchy - and on/off bunch of layers to "switch" between them
- Each composition - simple ruleset (on/off) over full paths of each node (node name + parents names)

# Limitations && Plans

- Planned: Base64 in image URIs (ok in buffers though)
- Not supported, planned: GLB format
- Not supported, no plannes: bone/armature, shapekeys, skinning, morth targets
- Planned: Some sort of automated atlas support. Auto-packing into atlas on request?
// Please note that atlas can be already utilized during scene creation by providing atlas textures on request

# Run demo

```
haxelib install openfl
haxelib install starling
cd ./demo
openfl test <win/mac/...>
```

- Demo using resources from https://opengameart.org/content/free-game-gui

# Run tests

```
haxelib install buddy
./get-samples.sh
cd ./test
haxe -x TestMain -lib buddy -p ../src
```

# gLTF loading based on haxe-gltf
haxe-gltf: A Haxe library for reading (and eventually, writing) [GLTF](https://github.com/KhronosGroup/glTF) files.

