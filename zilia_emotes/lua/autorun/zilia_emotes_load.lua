-- Loader de test en solo. À l'intégration : supprimer ce fichier et reporter ces lignes
-- dans roa_admin_system_load.lua (config avant sh_emotes, sh_emotes avant sv/cl, cl_emotedata en premier).
if SERVER then
	AddCSLuaFile("dev/shared/sh_emotes_config.lua")
	AddCSLuaFile("dev/shared/sh_emotes.lua")
	AddCSLuaFile("dev/client/cl_emotedata.lua")
	AddCSLuaFile("dev/client/cl_emotecamera.lua")
	AddCSLuaFile("dev/client/cl_emotepreview.lua")
	AddCSLuaFile("dev/client/cl_emotemenu.lua")

	include("dev/shared/sh_emotes_config.lua")
	include("dev/shared/sh_emotes.lua")
	include("dev/server/sv_emotes.lua")
	include("dev/server/sv_testbody.lua")

   resource.AddFile("resource/fonts/Poppins-Bold.ttf")
   resource.AddFile("resource/fonts/Poppins-Regular.ttf")
   resource.AddFile("resource/fonts/Manrope-Bold.ttf")
   resource.AddFile("resource/fonts/Manrope-SemiBold.ttf")
   resource.AddFile("sound/zilia_emotes/hover.wav")
   resource.AddFile("sound/zilia_emotes/tab.wav")
   resource.AddFile("sound/zilia_emotes/toggle.wav")
   resource.AddFile("sound/zilia_emotes/enter.wav")

	return
end

include("dev/shared/sh_emotes_config.lua")
include("dev/shared/sh_emotes.lua")
include("dev/client/cl_emotedata.lua")
include("dev/client/cl_emotecamera.lua")
include("dev/client/cl_emotepreview.lua")
include("dev/client/cl_emotemenu.lua")