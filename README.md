# Taxi Framework
The minimalist framework and game development philosophy that Taxi Simulator Future is based on.

## Actor-Based Game Development
Every component in your game should be an Actor, generally under ServerScriptService or StarterPlayerScripts. Actors should communicate with each other via a ModuleScript named Proxy parented to the Actor in question. General purpose ModuleScripts should be placed in ServerStorage.Modules and ReplicatedStorage.Modules. Actors in TaxiFramework represent self-contained components of your game, and may include anything from scripts, to Bindables, to game assets. The segregated nature of Actor-based development does a great job at coercing developers into writing [loosely coupled code](https://en.wikipedia.org/wiki/Coupling_%28computer_programming%29), as the flow of information between Actors is limited to only Bindables, the Actor messaging API (which is a glorified BindableEvent), and, rarely, the DataModel. It is also an excellent anti-exploit measure, because exploit compatibility with Actors is currently very poor, and most exploiters will only be able to run code on the main Luau state. One unwanted effect of this game development philosophy is that, unlike simply using ModuleScripts for each component of your game, Actors do not automatically wait for other Actors to load before interacting with them. To solve this problem, an Actor should mark itself as loaded with `Actor:SetAttribute("Loaded", true)` when it is ready to interact with other Actors, and its Proxy should yield all interactions with the Actor until it is marked as loaded. Loaded markers are enforced by the ReplicatedFirst.Loader Actor, which will wait an indefinite amount of time for all Actors to be loaded. It is not enforced on the Server-side, but not following the rule is considered bad practice because interactions with the Actor made before it is loaded will not be acknowledged. Continue reading for more information on Taxi Framework's built-in Actors.

## Client Loader
Taxi Framework includes a simple client loader that waits for all Actors in PlayerScripts to load before marking itself as loaded. By default, all it does is print when the game loads, specifying how long it took the game to load. The ReplicatedFirst.Loader.Callback ModuleScript runs instantly-before any Actors have loaded-upon joining the game, and returns a function to be called after all Actors have loaded. The recommended use case for ReplicatedFirst.Loader.Callback is for the developer to optionally add their own loading screen to the PlayerGui, optionally preload assets from the Roblox CDN, and then return a function that destroys the loading screen, if it was added, once the game has fully loaded. Note that the loader also ensures game:IsLoaded returns true before calling the callback. ReplicatedFirst.Loader has no Proxy.

## DataStore System
Taxi Framework includes a powerful DataStore system, based on Suphi's DataStore Module, that includes:
- All Suphi's DataStore Module features, such as session locking.
- Automatic save data loading upon joining the game.
- Cross-state functionality
- Changed Events
- Save file data replication to the client, on a need-to-know basis.

### Actor Breakdown
These features come in a total of three Actors:
- ServerScriptService.SaveDataLoader loads player data upon joining, and saves it automatically during gameplay, and upon leaving. Its Proxy implements Changed events for all values in the save file.
- ServerScriptService.SaveDataReplicator handles requests from the StarterPlayerScripts.SaveDataClient Actor, returning requested information to the client if allowed by the ServerStorage.Modules.SaveFileTemplate, and calling a ban function if it is not. It also replicates custom Changed events to the client for values in the save file. ServerScriptService.SaveDataReplicator has no Proxy.
- StarterPlayerScripts.SaveDataClient requests information about the player's save file from the server. Its Proxy provides an API for doing so, and provides the Changed events.

### The ServerStorage.Modules.SaveFileTemplate
TaxiFrameworks' save file template is similar to what you would expect if you have previous experience with ProfileService or Suphi's DataStore Module. TaxiFramework, however, has one very important difference: metadata. The metadata defines what information the client is allowed to access. The client has two means of requesting information: requesting specific values (get), and iterating through a table value (iter). With no metadata, all get requests are allowed, and no iter requests are allowed. When the ServerScriptService.SaveDataReplicator processes a get request, it keeps track of both the values it parses through in the save file, and the values in the template. For every table the server searches through to get the final value, it checks for an associated [metatable](https://create.roblox.com/docs/luau/metatables) in the template for a function called `index` (named after, and not to be confused with the metamethod `__index`). If it exists, the server calls it, passing the value in the save file and the key it wants to index next as arguments. If `index` returns true, the request proceeds as normal. If it returns false, the player is marked for ban using the ServerStorage.Modules.SaveFileManipulator.Ban module. If a client requests an iter operation on a table, the ServerScriptService.SaveDataReplicator looks for an `iter` function (once again, not to be confused with `__iter`) in only the final metatable in the template for the client's request. If the `iter` function does not exist, the player is marked for ban. If it does, the `iter` function is called with the value in the save file, and key, for every value in the table. The ServerScriptService.SaveDataReplicator will inform the client only of the values that `iter` returns true for.
The final metadata concept in the save file template is generics. To give an example, say you want to store several, arbitrarily named tables inside of another table in the save file. For example:
```lua
{
	Taxis = {
		Default = {
			...
		},
		Junker = {
			... --same values as the default
		},
		Pizza = {
			... --same values as the junker
		}
	}
}
```
Using generics, this large template can be consolidated into:
```lua
{
	Taxis = setmetatable({
		TaxiId = {
			...
		}
	}, {
		generic = TaxiId
	})
}
```
Using generics this way, requests to `SaveFile.Taxis.Default[...]` will follow the same metadata rules as `Template.Taxis.TaxiId[...]`. Note that the client's request will only work if `SaveFile.Taxis.Default` already exists in the save file, and will otherwise ban the player for requesting invalid data.

## Final Thoughts
That's it! That is everything included in the framework. I believe that good Roblox code has very vanilla APIs, which is why TaxiFramework only includes a DataStore system, client loader, and an Actor-based philosophy. The DataStore system is not vanilla at all, but it is included because many important features, such as session locking, just do not exist within the vanilla APIs. Including a Network module, for example, would alienate any developer only accustomed to Remotes when the benefit of using a Network module over remotes is very little.