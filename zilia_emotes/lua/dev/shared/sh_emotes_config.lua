-- ID est la clé des favoris et raccourcis enregistrés chez les joueurs, ne jamais le modifier une fois en jeu.
ZiliaEmotes = ZiliaEmotes or {}

-- Inclinaison de la vue pendant une emote : négatif = vers le haut, -89 au maximum.
-- La tête s'arrête d'elle-même à la limite prévue par le modèle.
ZiliaEmotes.LookPitch = 1

-- Touche qui arrête l'emote immédiatement, sans phase End (lancer de Pokéball sur le serveur)
ZiliaEmotes.ThrowKey = KEY_R

-- Touches refusées pour les raccourcis, en plus de celles liées au déplacement, au saut et à l'accroupi
ZiliaEmotes.BlockedBindKeys = {
	[KEY_K] = true,
	[KEY_L] = true,
	[KEY_M] = true,
	[KEY_R] = true,
	[KEY_J] = true,
	[KEY_P] = true,
}

ZiliaEmotes.Categories = {
	{ID = "dances", Name = "Dances"},
	{ID = "poses", Name = "Poses"},
	{ID = "sits", Name = "Sits"},
	{ID = "actions", Name = "Actions"},
}

ZiliaEmotes.List = {
	{ID = "arms_crossed", Category = "poses", Name = "Bras Croisés", Loop = "nb_d21_lobby_win_loop"},
	{ID = "thinking", Category = "poses", Name = "Réflexion", Start = "nb_orochimaru_etc_team_fin_start", Loop = "nb_orochimaru_etc_team_fin_loop", End = "nb_orochimaru_etc_team_fin_end"},
	{ID = "dance_wavy", Category = "dances", Name = "Vague de Bras", Start = "nb_emote_wave_type01_start", Loop = "nb_emote_wave_type01_loop", End = "nb_emote_wave_type01_end"},
	{ID = "dance_shadowboxing", Category = "dances", Name = "Haymaker Valley", Start = "nb_emote_sports_type03_start", Loop = "nb_emote_sports_type03_loop", End = "nb_emote_sports_type03_end"},
	{ID = "arms_crossed2", Category = "poses", Name = "Bras Croisés 2", Loop = "nb_tobirama_lobby_win_loop"},
	{ID = "arms_crossed3", Category = "poses", Name = "Bras Croisés 3", Loop = "nb_kisame_lobby_win_loop"},
	{ID = "awkward_scratch", Category = "actions", Name = "Air Gêné", Loop = "nb_shikamaru_etc_win_type01_start"},
	{ID = "crouched_sit", Category = "sits", Name = "Position Accroupie", Start = "nb_shikamaru_etc_team_type1_wait_start", Loop = "nb_shikamaru_etc_team_type1_wait_loop", End = "nb_shikamaru_etc_team_type1_wait_end"},
	{ID = "ready_to_fight", Category = "actions", Name = "Prêt au Combat", Loop = "nb_sakura_etc_win_type01_start"},
	{ID = "elegant", Category = "actions", Name = "Élégance", Loop = "nb_neji_etc_win_type01_start"},
	{ID = "fist_palm", Category = "poses", Name = "En Garde", Loop = "nb_naruto_lobby_win_loop"},
	{ID = "arm_guard", Category = "poses", Name = "Garde Levée", Loop = "nb_lobby_shootman_win_loop"},
	{ID = "hip_pose", Category = "poses", Name = "Déhanché", Loop = "nb_lobby_shootwoman_win_loop"},
	{ID = "hip_pose2", Category = "poses", Name = "Déhanché2", Loop = "nb_lobby_attackwoman_win_loop"},
	{ID = "hand_on_hip", Category = "poses", Name = "Mains sur Hanches", Loop = "nb_madarazombie_lobby_win_loop"},
	{ID = "ready_to_fight2", Category = "actions", Name = "Prêt au Combat 2", Loop = "nb_naruto_etc_win_type01_start"},
	{ID = "ready_to_fight3", Category = "actions", Name = "Prêt au Combat 3", Loop = "nb_lobby_defendman_win_loop"},
	{ID = "zombie_pose", Category = "poses", Name = "Position Zombie", Start = "nb_orochimaru_etc_team_type1_wait_start", Loop = "nb_orochimaru_etc_team_type1_wait_loop", End = "nb_orochimaru_etc_team_type1_wait_end"},
	{ID = "fist_pump", Category = "poses", Name = "Poing Serré", Loop = "nb_lobby_healman_win_loop"},
	{ID = "fist_up", Category = "poses", Name = "Poing Levé", Loop = "nb_lobby_attackman_win_loop"},
	{ID = "chest_puff", Category = "poses", Name = "Torse Bombé", Loop = "nb_lobby_d26styleman_win_loop"},
	{ID = "elegant_position", Category = "poses", Name = "Position Élégante", Loop = "nb_lobby_d26stylewoman_win_loop"},
	{ID = "fist_on_hip", Category = "poses", Name = "Poing sur Hanches", Loop = "nb_lobby_defendwoman_win_loop"},
	{ID = "fist_on_hip2", Category = "poses", Name = "Poing sur Hanches 2", Loop = "nb_jiraiya_lobby_win_loop"},
	{ID = "hand_on_heart", Category = "poses", Name = "Main sur le Coeur", Loop = "nb_lobby_healwoman_win_loop"},
	{ID = "hands_pocket", Category = "poses", Name = "Mains dans les Poches", Loop = "nb_kakashi_lobby_win_loop"},
	{ID = "proud_fist", Category = "actions", Name = "Poing Fier", Loop = "nb_kiba_etc_team_fin"},
	{ID = "respects", Category = "actions", Name = "Respects", Loop = "nb_lee_etc_win_type01_start"},
	{ID = "respects2", Category = "actions", Name = "Respects 2", Loop = "nb_kisame_etc_team_fin"},
	{ID = "respects3", Category = "actions", Name = "Respects 3", Loop = "nb_jiraiya_etc_team_fin"},
	{ID = "relaxed", Category = "poses", Name = "Décontracté", Loop = "nb_itachi_lobby_win_loop"},
	{ID = "evil_facepalm", Category = "actions", Name = "Evil awake gênant", Loop = "nb_kabuto_etc_win_type01_start"},
	{ID = "salute", Category = "actions", Name = "Salutations", Loop = "nb_iruka_etc_team_fin"},
	{ID = "no_finger", Category = "actions", Name = "Non", Loop = "nb_kabuto_etc_team_fin"},
	{ID = "martial_salute", Category = "actions", Name = "Salut Art Martial", Start = "nb_kabutocloak_etc_team_type1_wait_start", Loop = "nb_kabutocloak_etc_team_type1_wait_loop", End = "nb_kabutocloak_etc_team_type1_wait_end"},
	{ID = "thinking2", Category = "poses", Name = "Réflexion 2", Loop = "nb_hiruzen_lobby_win_loop"},
	{ID = "fist_pump2", Category = "poses", Name = "Poing Serré 2", Loop = "nb_hashirama_lobby_win_loop"},
	-- {ID = "dance_1", Category = "dances", Name = "Danse", Start = "d1_start", Loop = "d1_loop", End = "d1_end"},
}