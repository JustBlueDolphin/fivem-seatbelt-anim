# Seatbelt animations and toggle

**Made with AI** - the custom animations and FiveM script were created with AI assistance.

Standalone client resource with four custom clips: buckle/unbuckle for left- and right-side seating. Arm movement only, as requested. Includes a configurable **B** key and `/seatbelt` command, support for drivers and passengers, an exit-button lock while fastened, and optional suppression of GTA's built-in windscreen ejection flag while fastened.

[Watch the four animations](previews/seatbelt-preview.mp4)

## Install

Copy the complete `seatbelt_anim` folder into your server resources and add:

```cfg
ensure seatbelt_anim
```

Use a car, SUV, van, truck or bus. Press **B** to fasten/release, or use:

```text
/seatbelt
/seatbelt on
/seatbelt off
/seatbelt status
```

The B key can be remapped in FiveM's key bindings. Configured keys only set the initial binding. Vehicle classes and model exclusions can be changed in `config.lua`. Bikes, bicycles, boats, aircraft and trains are excluded because these clips use a seated car pose.

The belt changes state after a successful gesture, not when the button is first pressed. A second press while the gesture is running is rejected. Missing dictionaries, missing clips, failed playback and interrupted gestures leave the belt state unchanged. Exiting, changing vehicles/seats, dying or changing player ped clears the state. Resource shutdown restores the previous ped ejection flag and stops only this resource's gesture. The exit block is applied each frame and ends when the belt is released.

## Behaviour and integration

Left-side seating reaches from the outer left shoulder to the inner right hip with the right hand; right-side seating uses the left hand. Seating side is inferred from the ped's position relative to the vehicle. Per-model `side` overrides are available for unusual interiors. A centrally positioned seat defaults to left-side seating.

Other client scripts can use:

```lua
local ok, reason = exports['seatbelt_anim']:Toggle()
local ok, reason = exports['seatbelt_anim']:SetBuckled(true)
local wearing = exports['seatbelt_anim']:IsBuckled()
local busy = exports['seatbelt_anim']:IsBusy()

AddEventHandler('seatbelt_anim:changed', function(fastened, vehicle)
    -- Update your HUD here. This is a local client event.
end)
```

`Toggle` and `SetBuckled` return immediately. `true, 'started'` means the asynchronous animation began loading; the `changed` event reports successful completion. Other results include `unchanged`, `busy`, `ped_busy`, `invalid_state` and `not_in_supported_vehicle`. Use one seatbelt implementation at a time; existing framework seatbelt/ejection scripts may conflict. This resource has no server-side state, custom crash/ejection physics, visible strap or seatbelt prop.

The optional built-in ejection setting sets ped config flag 32 false while fastened and restores the value captured before fastening. It does not override another resource's independent crash/ejection logic. Disabling the setting leaves that flag alone. See the [Cfx native flag definitions](https://github.com/citizenfx/natives/blob/master/PED/SetPedConfigFlag.md).

These gestures share GTA's secondary animation task slot with other resources, including gearshift scripts. Try the gestures while parked; a competing shift animation may interrupt them. Interrupted playback does not commit the new belt state.

## Validation and credits

The four YCD clips passed a CodeWalker save/reload check and an elbow continuity check. Offline mocked Lua tests cover both seating sides, passengers, state transitions, exit controls, interrupted/missing playback, context changes, prior-flag restoration and resource shutdown. These checks do **not** verify actual FiveM playback, collision protection or vehicle-specific fit.

The MP male ped was used for preview. The MP female shares the arm/hand bone IDs, but female positioning and different clothing/vehicle interiors still require in-game checks. Buckle duration is 2.4 seconds; unbuckle duration is 1.8 seconds.

Preview footage uses Rockstar Games' GTA V multiplayer ped and Sultan vehicle models. Those third-party models are visual references and are not included as game assets. The custom animations and script are the AI-assisted deliverables. No ownership of Rockstar assets or unrelated third-party work is claimed.

The playback call uses the `startPhase = 0.0` and per-task arm-IK control flags documented by [ox_lib's native wrapper](https://github.com/overextended/ox_lib/blob/master/imports/playAnim/client.lua). The resource does not require ox_lib.
