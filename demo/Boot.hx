package;

import openfl.system.Capabilities;
import openfl.system.System;
import openfl.errors.Error;
import openfl.geom.Rectangle;
import openfl.display.Sprite;

import gltf.*;
import starling.gltf.*;
import starling.core.Starling;
import starling.display.Stage;
import starling.events.Event;
import starling.assets.*;
import starling.display.*;

class Boot extends Sprite
{
	private var _starling:Starling;
	public function new()
	{
		super();
		if (stage != null) {
			startStarling();
		}else {
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		}
	}

	private function onAddedToStage(event:Dynamic):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		startStarling();
	}

	private function startStarling():Void
	{
		trace("!!!");
	}
}