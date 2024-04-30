# PFFAnim2d - Simple (2d) gLTF animation support in OpenFL/Starling
- Intended workflow: Krita -> Blender animations -> gLTF -> OpenFL+Starling game
- Supported: TRS animations of Blender Empty/Blender Plane(Quad)
- Somewhat supported: Alpha animation, Clipping rect animation (sprite masking) - see below

# Compositions:
- Compositions can be used to alter visibility of nodes en-masse. Named after similar feature in Krita.
- Each composition consist of simple ruleset (on/off) over full paths of each node (node name + parents names)
- With compositions it is possible to create several UIs in one hierarchy and on/off bunch of layers to "switch" between them

# Blender setup details
- Recognizable objects: Empties for grouping and simple Mesh objects (quad, 4-vert plane) for starling sprites
- Empties && Quads arrangement: Blender XZ-plane (for front view). Y is used as "depth" (-Y defines rendering order)
  - In world coords, root empty should not have any rotations/scales
- Textures: Quads should have unlit textures - quad material image used for corresponding starling node (by default)
- Pivot: Quad can have axis-aligned offset from object origin, offset converted to Sprite pivot (by default)
- CustomProps: Quad/Empty can have custom props, they are loaded and can be used for customizing starling node creation/custom logic
- Z-Order: Quad/Empty loc.Y define draw order (in Starling) for same-level elements.
  - Draw order fixed by scene basic (not animated) state
- Animations: Actions must be stashed (Dopesheet-Action Editor) or pushed to NLA track (NLA Editor)
  - Export name will be the name of the action in both cases
- Animations: Actions must always have frame 0 keyed
  - gLTF 'Actions' exporter resets any timeline offset anyway
- Animations: Armature animations are not supported directly - they need to be baked on valid objects before export
- Blender export options: `Format: gLTF Separate`, `Include: Selected Objects, Custom Properties`, `Transform: Y Up: On`, `Data: Mesh: UVs`, `Material: Export`, `Shape Keys: Off`, `Skinning: Off`, `Lighting: Unitless`, `Animation: On`, `Animation: Mode: Actions`, `Animation: Sample Animations: Off`
  - Z-up/Y-up: Blender importer always counter-rotate imported file, so with 'Y Up: On' front-view export ends up in Z-up in exported gltf scene, but reimport/reexport works well

# Alpha && Clipping animation conventions

gLTF does not support non-TRS animation targets. So some extra efforts required to make it happen with Blender && gLTF.
1) Basic alpha derived from node's Scale Y (Blender Y-axis), since it's not used for 2D scaling and defaults to 1.0. Named `alpha_self` in hx
- Material nodes with such alpha support [here](demo/demo_art/blender_mat_ScaleY_as_alpha.png)
2) Animated clipping: some Nodes are served as "placeholders" for holding such animations.
- Each Empty can contain Plane (quad) Mesh object with the name "#pff:mask". Such object have special meaning for animation in Starling
- Plane (Quad) rectangle = clipping rect for parent DisplayObjectContainer

# Limitations && Plans

- [ ] Planned: Base64 in image URIs
- [ ] Planned: GLB format
- [ ] Planned: Optimization: avoid vector.copy/array.push during animation interp/apply
- [ ] Planned: Alpha-quality options per node
  - There is a problem with alpha fades over overlapping child - overlaps are visible on sub-images
  - Options: basic (per-sprite), push-to-childs (ok for simple hiers), filter-flattening (root sprite rendered offscreen with alpha 1.0 first)
- [ ] Planned: Optimization: Some sort of automated atlas support - Auto-packing into atlas on load
  - currently atlas can be utilized simply by providing atlas textures on request during scene creation
- [x] Done: Base64 in buffers URIs
- [x] Done: Respect nodes z-order for starling sprites layout
- [ ] Not supported, not planned: bones/armatures/skinning, shapekeys/morth targets, cameras, etc etc
  - Spine better suited for this, https://github.com/EsotericSoftware/spine-runtimes/

# Run demo

```
haxelib install openfl
haxelib install starling
cd ./demo
openfl test <windows/mac>
```

- Demo using resources from https://opengameart.org/content/free-game-gui
- Blend file used for gLTF export can be found in `./demo_art`

# Run tests

```
haxelib install buddy
./get-samples.sh
cd ./test
haxe -x TestMain -lib buddy -p ../src
```

---

> [!NOTE]
> gLTF parsing & loading based on https://github.com/hamaluik/haxe-gltf
> haxe-gltf: A Haxe library for reading (and eventually, writing) [GLTF](https://github.com/KhronosGroup/glTF) files.

