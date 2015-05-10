if not SERVER then return end

PocketSave = {}
PocketSave.Configs = {}

PocketSave.Configs.Debug = true // Debug mode?
// Debug mode activates the following:
// 1. Log this addon's initialization time
// 2. Adds a command to get this addon's initialization time
// 3. Prints whenever a item has been added/removed from a player's pocket
// 4. Prints whenever a pocket is being saved/loaded
// Apart from these it won't affect anything


PocketSave.Configs.Compress = true // Compress saves?
// Compressing saves will reduce the size of each save,
// but it might raise the saving time a little.
// I'd reccomend you enable debug mode and use the "psave_benchmark" command
// before setting this config.

//////////////////////////////////////////////////////////////////////////
///  Don't mess past this point unless you know what you are doing     ///
//////////////////////////////////////////////////////////////////////////

///////////////////////
// Configs acronyms  //
///////////////////////
local dbg = PocketSave.Configs.Debug
local cps = PocketSave.Configs.Compress

///////////////////////
//       Stuff       //
///////////////////////
local istart
local log = function(a,...) // Fancy logging function
	if(a and type(a) == "bool" and !dbg)then return end
	MsgN("[PocketSave]: ",(type(a)=="string" and a or ""),...)
end

log("Initializing")
if(dbg)then
	istart = SysTime()
end
///////////////////////
// Utility functions //
///////////////////////
function PocketSave.FileSystemCheck() // Functions which checks if the folder on the data folder was created correctly
	log("Checking filesystem")
	if not file.Exists("psave", "DATA") then // If it doesn't exists
		log(true,"Creating folder on data path") // Log the folder creation only if its on debug mode
		file.CreateDir("psave") // Creates as directory
	end
	
	if not file.IsDir( "psave", "DATA" ) then // If its the wrong type
		log(true,"Creating folder on data path") // Log that shit happened only if its on debug mode
		file.Delete( "psave" ) // Delete the wrongly created file/folder
		file.CreateDir( "psave" ) // Create as directory
	end
end

function PocketSave.SaveTbl( sid, tbl, cm ) // Function to save a table of items by SteamID
	cm=(cm and cm or true)
	PocketSave.FileSystemCheck() // Make a filesystem check
	local items = util.Compress(util.TableToJSON(tbl or {})) // Compress the items' JSON
	local fname = string.lower("pocket_"..string.Replace(sid, ":", "_")) // Get the file name which the pocket will be saved to
	log(true,"Saving the pocket of ",sid) // Tell that we're saving the pocket of the player only if its on debug mode
	file.Write("psave/"..fname..".txt", items) // Save the pocket
end


///////////////////////
//  Hooks functions  //
///////////////////////

function PocketSave.Initialize()
	log("Initializing")
	PocketSave.FileSystemCheck() // Check if the folder is set correctly...
end

function PocketSave.PlayerInitialSpawn(ply)
	local SteamID = ply:SteamID() // SteamID since everything is SteamID based
	
	log(true,"Retrieving the pocket of ",SteamID)
	if(!file.Exists("psave/pocket_"..string.Replace(SteamID, ":", "_")..".txt", "DATA"))then return end // The player doesn't has anything on his/her pocket
	
	local ptbl = util.JSONToTable( // Convert from JSON
		util.Decompress( // Decompress file
			file.Read( // Read file
				"psave/"string.lower("pocket_"..string.Replace(SteamID, ":", "_"))..".txt", // File name
				"DATA"
			) or ""
		) or {}
	)
	
	ply.darkRPPocket = ptbl
	net.Start("DarkRP_Pocket") net.WriteTable(ptbl) net.Send(ply)
end

function PocketSave.onPocketItemAdded( ply, _, serialized )
	local itbl = ply.darkRPPocket // Make a temporary table
	itbl = table.insert(itbl, serialized) // Add the picked/added item since we recieve the unchanged table
	PocketSave.SaveTbl( ply:SteamID(), itbl ) // Update by SteamID
end

function PocketSave.onPocketItemRemoved( ply, item )
	local itbl = ply.darkRPPocket // Make a temporary table
	itbl[item] = nil // Remove the dropped/removed item since we recieve the unchanged table
	PocketSave.SaveTbl( ply:SteamID(), itbl ) // Update by SteamID
end

function PocketSave.PlayerDisconnected(ply)
	PocketSave.FileSystemCheck() // Make a filesystem check(yeah, I know we made it on Initialization, but checks are never enough)
	local items = util.Compress(util.TableToJSON(ply.darkRPPocket or {})) // Compress the items' JSON
	local fname = string.lower("pocket_"..string.Replace(ply:SteamID(), ":", "_")) // Get the file name which the pocket will be saved to
	log(true,"Saving the pocket of ",ply:SteamID()) // Tell that we're saving the pocket of the player
	file.Write("psave/"..fname..".txt", items) // Save the pocket
end

local addHook = function(name) hook.Add( name, "PocketSave.Hook."..name, PocketSave[name] ) end // Cbf to type so much
local remHook = function(name) hook.Remove( name, "PocketSave.Hook."..name ) end // Not used but good to have around just in case

addHook( "Initialize" ) // Initialize pocket saving system
addHook( "PlayerInitialSpawn" ) // Sends items on join
addHook( "onPocketItemAdded" ) // Saves when an item is picked up
addHook( "onPocketItemRemoved" ) // Saves when an item is dropped/removed
addHook( "PlayerDisconnected" ) // Saves when player disconects

log("Done!")

if(dbg)then // Debug functions and console commands
	PocketSave.LoadTime = math.Round( SysTime() - istart, 4) // Don't need huge ass numbers
	local ltls = string.format( "Initialization took %g second(s)", PocketSave.LoadTime )
	log(ltls) // Shows initialization time
	concommand.Add("psave_loadtime",function(ply) // Debug stuff only
		if(!p:IsSuperAdmin())then return end
		if(ply:IsValid())then ply:SendLua([[MsgN("[PocketSave] ]] .. ltls .. [[ ")]])
		else MsgN(ltls) end
	end)
	
	local dbg_save_cm = function( ply )
		local s = SysTime()
		local items = util.Compress(util.TableToJSON(ply.darkRPPocket or {}))
		local fname = string.lower("dbg_save_cm_"..string.Replace(ply:SteamID(), ":", "_"))
		file.Write("psave/"..fname..".txt", items)
		return math.Round((SysTime()-s),4),file.Size( "psave/"..fname..".txt", "DATA" )
	end
	
	local dbg_save_nm = function( ply )
		local s = SysTime()
		local items = util.TableToJSON(ply.darkRPPocket or {})
		local fname = string.lower("dbg_save_nm_"..string.Replace(ply:SteamID(), ":", "_"))
		file.Write("psave/"..fname..".txt", items)
		return math.Round((SysTime()-s),4),file.Size( "psave/"..fname..".txt", "DATA" )
	end
	
	local aa = function(ntbl)
		local average = 0
		for _,num in pairs(ntbl) do average = average + num end
		return (average/table.Count(ntbl))
	end
	
	concommand.Add("psave_benchmark",function(p)
		if(!p:IsSuperAdmin())then return end
		local dlog=function(...)
			if p:IsValid() then
				p:SendLua([[MsgN("[PocketSave][Debug]: ]]..table.concat({...})..[[")]])
			else
				MsgN("[PocketSave][Debug]: ",...)
			end
		end
		ply = player.GetAll()[1]
		MsgN("")
		dlog("Starting save benchmark...")
		dlog("Benckmarck subject will be ",ply:Nick(),"'s pocket, please be sure that there're items on it.")
		local bdt1 = {}
		bdt1.time = {}
		bdt1.size = {}
		
		for i=0,GM.Config.pocketitems do
			local time,size = dbg_save_cm(ply)
			table.insert(bdt1.time,time)
			table.insert(bdt1.size,size)
		end
		local ct = aa(bdt1.time)
		local cs = aa(bdt1.size)
		
		local bdt2 = {}
		bdt2.time = {}
		bdt2.size = {}
		
		for i=0,GM.Config.pocketitems do
			local time,size = dbg_save_nm(ply)
			table.insert(bdt2.time,time)
			table.insert(bdt2.size,size)
		end
		local ut = aa(bdt2.time)
		local us = aa(bdt2.size)
		dlog("Benchmark done, the results are:")
		dlog(string.format("Average uncompressed saving time: %gs",math.Round(ut,4)))
		dlog(string.format("Average uncompressed saving size: %g bytes",us))
		dlog("-------------------------------------------")
		dlog(string.format("Average compressed saving time: %gs",math.Round(ct,4)))
		dlog(string.format("Average compressed saving size: %g bytes",cs))
		dlog("-------------------------------------------")
		dlog("Final results are:")
		if(ct<ut) then
			dlog(string.format("Compressed saving time is smaller, taking %g less seconds than the uncompressed",math.Round(ut-ct,4)))
		else
			dlog(string.format("Compressed saving time is higher, taking %g more seconds than the uncompressed",math.Round(ct-ut,4)))
		end
		if(cs<us) then
			dlog(string.format("Compressed saves' size is smaller, with %i less bytes than the uncompressed",(us-cs)))
		else
			dlog(string.format("Compressed saves' size is bigger, with %i more bytes than the uncompressed",(cs-us)))
		end
		local td = (math.Round(ut-ct,4)>math.Round(ct-ut,4) and math.Round(ut-ct,4) or math.Round(ct-ut,4))
		local sd = ((us-cs)>(cs-us)and(us-cs)or(cs-us))
		if(td<0.0015 or sd > 2000)then
			dlog("As of the results of this test, our recomendation is that you use the compressed mode since the saving time is not so affected by it and/or the gap between the saving sizes is too big.")
		else
			dlog("As of the results of this test, our recomendation is that you do not use the compressed mode since the saving time is heavily affected by it and/or the gap between the saving sizes isn't too big.") // Even thought I like the compressed mode I have to tell the truth
		end
		MsgN("")
	end)
	
	concommand.Add("psave_massivedrop",function(ply)
		if(!p:IsSuperAdmin())then return end
		timer.Create("psave_mdrop",.01,10,function()
			ply.anim_DroppingItem = false
			ply:dropDRPWeapon(ply:Give("m9k_ak47"))
			ply.anim_DroppingItem = true
		end)
	end)
end