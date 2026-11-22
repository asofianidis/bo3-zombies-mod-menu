/*
	BO3 Zombies Mod Menu
	--------------------
	Overrides the stock scripts\zm\gametypes\_clientids.gsc, which every zombies map
	loads through scripts\zm\_load.gsc. The stock client-id logic is kept intact.

	Controls (host only):
		Open menu ........ [ADS] + [Melee]
		Scroll ........... [ADS] up / [Fire] down
		Select ........... [Use]
		Back / Close ..... [Melee]
*/

#using scripts\codescripts\struct;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai\zombie_utility;
#using scripts\zm\_zm;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#insert scripts\shared\shared.gsh;

#namespace clientids;

#define MM_ROWS 10
#define MM_ROW_H 16
#define MM_WIDTH 230
#define MM_X 140
#define MM_Y 110

REGISTER_SYSTEM("clientids", &__init__, undefined)

// ---------------------------------------------------------------------------
// Bootstrap (stock behaviour + menu hook)
// ---------------------------------------------------------------------------

function __init__()
{
	callback::on_start_gametype(&init);
	callback::on_connect(&on_player_connect);
}

function init()
{
	level.clientid = 0;
}

function on_player_connect()
{
	// Stock _clientids behaviour
	self.clientid = matchRecordNewPlayer(self);
	if(!isdefined(self.clientid) || self.clientid == -1)
	{
		self.clientid = level.clientid;
		level.clientid++;
	}

	if(self isHost())
	{
		self thread mm_init();
	}
}

// ---------------------------------------------------------------------------
// Menu core
// ---------------------------------------------------------------------------

function mm_init()
{
	self endon("disconnect");

	self.mm_open = false;
	self.mm_hud_built = false;
	self.mm_t = [];          // toggle states
	self.mm_stack = [];      // parent menu ids
	self.mm_stack_cursor = [];
	self.mm_menu = "main";
	self.mm_cursor = 0;
	self.mm_scroll = 0;
	self.mm_opts = [];

	self waittill("spawned_player");
	wait 2;
	self iPrintLn("^5Mod Menu ^7loaded - press ^3[{+speed_throw}] ^7+ ^3[{+melee}] ^7to open");

	self thread mm_controls();
}

function mm_controls()
{
	self endon("disconnect");

	for(;;)
	{
		if(!self.mm_open)
		{
			if(self adsButtonPressed() && self meleeButtonPressed())
			{
				self mm_open_menu();
				while(self meleeButtonPressed())
					wait 0.05;
			}
		}
		else
		{
			if(self adsButtonPressed())
			{
				self mm_scroll(-1);
				wait 0.12;
			}
			else if(self attackButtonPressed())
			{
				self mm_scroll(1);
				wait 0.12;
			}
			else if(self useButtonPressed())
			{
				self mm_select();
				while(self useButtonPressed())
					wait 0.05;
			}
			else if(self meleeButtonPressed())
			{
				self mm_back();
				while(self meleeButtonPressed())
					wait 0.05;
			}
		}
		wait 0.05;
	}
}

function mm_open_menu()
{
	if(!self.mm_hud_built)
		self mm_build_hud();

	self.mm_open = true;
	self disableWeapons();
	self.mm_stack = [];
	self.mm_stack_cursor = [];
	self mm_load("main", 0);
	self mm_set_visible(true);
}

function mm_close_menu()
{
	self.mm_open = false;
	self mm_set_visible(false);
	if(!self mm_is_on("ufo"))
		self enableWeapons();
}

function mm_back()
{
	if(self.mm_stack.size == 0)
	{
		self mm_close_menu();
		return;
	}

	idx = self.mm_stack.size - 1;
	parent = self.mm_stack[idx];
	cursor = self.mm_stack_cursor[idx];
	ArrayRemoveIndex(self.mm_stack, idx);
	ArrayRemoveIndex(self.mm_stack_cursor, idx);
	self mm_load(parent, cursor);
}

function mm_enter(id)
{
	self.mm_stack[self.mm_stack.size] = self.mm_menu;
	self.mm_stack_cursor[self.mm_stack_cursor.size] = self.mm_cursor;
	self mm_load(id, 0);
}

function mm_load(id, cursor)
{
	self.mm_menu = id;
	self.mm_opts = [];
	self.mm_title = "MOD MENU";
	self mm_build_menu(id);

	if(cursor >= self.mm_opts.size)
		cursor = 0;
	self.mm_cursor = cursor;
	self.mm_scroll = 0;
	if(self.mm_cursor >= MM_ROWS)
		self.mm_scroll = self.mm_cursor - MM_ROWS + 1;

	self mm_draw();
}

function mm_scroll(dir)
{
	if(self.mm_opts.size == 0)
		return;

	self.mm_cursor += dir;
	if(self.mm_cursor < 0)
		self.mm_cursor = self.mm_opts.size - 1;
	if(self.mm_cursor >= self.mm_opts.size)
		self.mm_cursor = 0;

	if(self.mm_cursor < self.mm_scroll)
		self.mm_scroll = self.mm_cursor;
	if(self.mm_cursor >= self.mm_scroll + MM_ROWS)
		self.mm_scroll = self.mm_cursor - MM_ROWS + 1;

	self mm_draw();
}

function mm_select()
{
	if(self.mm_opts.size == 0)
		return;

	opt = self.mm_opts[self.mm_cursor];
	if(isdefined(opt.submenu))
	{
		self mm_enter(opt.submenu);
		return;
	}

	if(isdefined(opt.func))
		self thread [[opt.func]](opt.arg);

	// Refresh toggle indicators after the option runs
	wait 0.05;
	if(self.mm_open)
		self mm_draw();
}

// ---------------------------------------------------------------------------
// Option builders
// ---------------------------------------------------------------------------

function add_opt(label, func, arg, toggle_key)
{
	o = SpawnStruct();
	o.label = label;
	o.func = func;
	o.arg = arg;
	o.toggle = toggle_key;
	self.mm_opts[self.mm_opts.size] = o;
}

function add_sub(label, id)
{
	o = SpawnStruct();
	o.label = label + " >";
	o.submenu = id;
	self.mm_opts[self.mm_opts.size] = o;
}

function mm_is_on(key)
{
	return isdefined(self.mm_t[key]) && self.mm_t[key];
}

// ---------------------------------------------------------------------------
// Menu structure
// ---------------------------------------------------------------------------

function mm_build_menu(id)
{
	switch(id)
	{
		case "main":
			self.mm_title = "MOD MENU";
			self add_sub("Player", "player");
			self add_sub("Weapons", "weapons");
			self add_sub("Perks", "perks");
			self add_sub("Power-Ups", "powerups");
			self add_sub("Zombies & Rounds", "zombies");
			self add_sub("Map", "map");
			self add_sub("Teleport", "teleport");
			self add_sub("Fun", "fun");
			break;

		case "player":
			self.mm_title = "PLAYER";
			self add_opt("God Mode", &tog_god, undefined, "god");
			self add_opt("Infinite Ammo", &tog_ammo, undefined, "ammo");
			self add_opt("Zombies Ignore Me", &tog_notarget, undefined, "notarget");
			self add_opt("UFO Mode (hold Fire to fly)", &tog_ufo, undefined, "ufo");
			self add_opt("Infinite Specialist", &tog_specialist, undefined, "specialist");
			self add_opt("+10,000 Points", &give_points, 10000);
			self add_opt("+100,000 Points", &give_points, 100000);
			self add_opt("+1,000,000 Points", &give_points, 1000000);
			self add_opt("Refill Health", &refill_health);
			break;

		case "weapons":
			self.mm_title = "WEAPONS";
			self add_opt("Pack-a-Punch Current Weapon", &pap_current);
			self add_opt("Max Ammo (all weapons)", &max_ammo_all);
			self add_opt("Take Current Weapon", &take_current);
			self add_sub("Give Weapon", "weapon_list");
			break;

		case "weapon_list":
			self.mm_title = "GIVE WEAPON";
			if(isdefined(level.zombie_weapons))
			{
				foreach(w in GetArrayKeys(level.zombie_weapons))
				{
					if(!isdefined(w) || w == level.weaponNone)
						continue;
					self add_opt(weapon_label(w), &give_weapon, w);
				}
			}
			if(self.mm_opts.size == 0)
				self add_opt("No weapons found", undefined);
			break;

		case "perks":
			self.mm_title = "PERKS";
			self add_opt("Give All Perks", &give_all_perks);
			self add_opt("Remove All Perks", &remove_all_perks);
			if(isdefined(level._custom_perks))
			{
				foreach(perk in GetArrayKeys(level._custom_perks))
					self add_opt(perk_name(perk), &give_one_perk, perk);
			}
			break;

		case "powerups":
			self.mm_title = "POWER-UPS";
			if(isdefined(level.zombie_include_powerups))
			{
				foreach(p in GetArrayKeys(level.zombie_include_powerups))
					self add_opt(powerup_name(p), &spawn_powerup, p);
			}
			if(self.mm_opts.size == 0)
				self add_opt("No power-ups found", undefined);
			break;

		case "zombies":
			self.mm_title = "ZOMBIES & ROUNDS";
			self add_opt("Kill All Zombies", &kill_all_zombies);
			self add_opt("One-Hit Kills", &tog_onehit, undefined, "onehit");
			self add_opt("Next Round", &round_skip, 1);
			self add_opt("Previous Round", &round_skip, -1);
			self add_opt("Go To Round 10", &round_goto, 10);
			self add_opt("Go To Round 20", &round_goto, 20);
			self add_opt("Go To Round 30", &round_goto, 30);
			self add_opt("Go To Round 50", &round_goto, 50);
			self add_opt("Go To Round 100", &round_goto, 100);
			break;

		case "map":
			self.mm_title = "MAP";
			self add_opt("Open All Doors & Debris", &open_all_doors);
			self add_opt("Turn On Power", &power_on);
			self add_opt("End Game", &end_game);
			break;

		case "teleport":
			self.mm_title = "TELEPORT";
			self add_opt("Save Position", &tp_save);
			self add_opt("Load Position", &tp_load);
			self add_opt("Teleport To Crosshair", &tp_crosshair);
			break;

		case "fun":
			self.mm_title = "FUN";
			self add_opt("Third Person", &tog_thirdperson, undefined, "thirdperson");
			self add_opt("Super Speed", &tog_speed, undefined, "speed");
			break;
	}
}

// ---------------------------------------------------------------------------
// HUD
// ---------------------------------------------------------------------------

function mm_build_hud()
{
	h = 30 + (MM_ROWS * MM_ROW_H) + 22;
	accent = (0.10, 0.65, 1.00);

	self.mm_hud = [];
	self.mm_hud["bg"] = self mm_icon(MM_X, MM_Y, MM_WIDTH, h, (0.05, 0.05, 0.07), 0.85, 1);
	self.mm_hud["header"] = self mm_icon(MM_X, MM_Y, MM_WIDTH, 26, accent, 0.95, 2);
	self.mm_hud["cursor"] = self mm_icon(MM_X, MM_Y + 30, MM_WIDTH, MM_ROW_H, accent, 0.45, 3);
	self.mm_hud["footer_line"] = self mm_icon(MM_X, MM_Y + h - 20, MM_WIDTH, 1, accent, 0.8, 2);

	self.mm_hud["title"] = self mm_text("TOP_LEFT", MM_X + 8, MM_Y + 5, 1.5, (1, 1, 1), 5);
	self.mm_hud["footer"] = self mm_text("TOP_LEFT", MM_X + 8, MM_Y + h - 16, 0.9, (0.75, 0.75, 0.75), 5);
	self.mm_hud["footer"] setText("[{+speed_throw}]/[{+attack}] Scroll  [{+activate}] Select  [{+melee}] Back");

	self.mm_hud["more_up"] = self mm_text("TOP_RIGHT", MM_X + MM_WIDTH - 8, MM_Y + 6, 1.2, (1, 1, 1), 5);
	self.mm_hud["more_down"] = self mm_text("TOP_RIGHT", MM_X + MM_WIDTH - 8, MM_Y + h - 40, 1.2, (1, 1, 1), 5);
	self.mm_hud["more_up"] setText("^");
	self.mm_hud["more_down"] setText("v");

	self.mm_rows = [];
	self.mm_states = [];
	for(i = 0; i < MM_ROWS; i++)
	{
		y = MM_Y + 30 + (i * MM_ROW_H) + 1;
		self.mm_rows[i] = self mm_text("TOP_LEFT", MM_X + 8, y, 1.1, (1, 1, 1), 5);
		self.mm_states[i] = self mm_text("TOP_RIGHT", MM_X + MM_WIDTH - 8, y, 1.1, (1, 1, 1), 5);
	}

	self.mm_hud_built = true;
	self mm_set_visible(false);
}

function mm_icon(x, y, w, h, color, alpha, sort)
{
	e = self hud::createIcon("white", w, h);
	e hud::setPoint("TOP_LEFT", "TOP", x, y);
	e.color = color;
	e.alpha = alpha;
	e.base_alpha = alpha;
	e.sort = sort;
	e.foreground = true;
	e.hideWhenInMenu = true;
	e.archived = false;
	return e;
}

function mm_text(align, x, y, scale, color, sort)
{
	e = self hud::createFontString("objective", scale);
	e hud::setPoint(align, "TOP", x, y);
	e.color = color;
	e.alpha = 1;
	e.base_alpha = 1;
	e.sort = sort;
	e.foreground = true;
	e.hideWhenInMenu = true;
	e.archived = false;
	return e;
}

function mm_set_visible(on)
{
	foreach(e in self.mm_hud)
	{
		if(on)
			e.alpha = e.base_alpha;
		else
			e.alpha = 0;
	}
	for(i = 0; i < MM_ROWS; i++)
	{
		if(on)
		{
			self.mm_rows[i].alpha = 1;
			self.mm_states[i].alpha = 1;
		}
		else
		{
			self.mm_rows[i].alpha = 0;
			self.mm_states[i].alpha = 0;
		}
	}
	if(on)
		self mm_draw();
}

// Only a small, fixed set of strings is ever passed to setText (option labels
// and ON/OFF), so the configstring pool does not overflow over long sessions.
function mm_draw()
{
	if(!self.mm_hud_built)
		return;

	self.mm_hud["title"] setText(self.mm_title);

	for(i = 0; i < MM_ROWS; i++)
	{
		idx = self.mm_scroll + i;
		if(idx < self.mm_opts.size)
		{
			opt = self.mm_opts[idx];
			self.mm_rows[i] setText(opt.label);
			if(isdefined(opt.toggle))
			{
				if(self mm_is_on(opt.toggle))
					self.mm_states[i] setText("^2ON");
				else
					self.mm_states[i] setText("^1OFF");
			}
			else
			{
				self.mm_states[i] setText("");
			}
		}
		else
		{
			self.mm_rows[i] setText("");
			self.mm_states[i] setText("");
		}
	}

	row = self.mm_cursor - self.mm_scroll;
	self.mm_hud["cursor"] hud::setPoint("TOP_LEFT", "TOP", MM_X, MM_Y + 30 + (row * MM_ROW_H));

	if(self.mm_scroll > 0)
		self.mm_hud["more_up"].alpha = 1;
	else
		self.mm_hud["more_up"].alpha = 0;

	if(self.mm_scroll + MM_ROWS < self.mm_opts.size)
		self.mm_hud["more_down"].alpha = 1;
	else
		self.mm_hud["more_down"].alpha = 0;
}

function mm_msg(text)
{
	self iPrintLn(text);
}

function mm_toggle(key)
{
	was_on = self mm_is_on(key);
	self.mm_t[key] = !was_on;
	return self.mm_t[key];
}

// ---------------------------------------------------------------------------
// Player options
// ---------------------------------------------------------------------------

function tog_god(arg)
{
	if(self mm_toggle("god"))
	{
		self mm_msg("God Mode ^2ON");
		self endon("disconnect");
		self endon("mm_god_off");
		for(;;)
		{
			self EnableInvulnerability();
			wait 0.25;
		}
	}
	else
	{
		self notify("mm_god_off");
		self DisableInvulnerability();
		self mm_msg("God Mode ^1OFF");
	}
}

function tog_ammo(arg)
{
	if(self mm_toggle("ammo"))
	{
		self mm_msg("Infinite Ammo ^2ON");
		self endon("disconnect");
		self endon("mm_ammo_off");
		for(;;)
		{
			w = self GetCurrentWeapon();
			if(isdefined(w) && w != level.weaponNone)
			{
				self SetWeaponAmmoClip(w, w.clipSize);
				if(isdefined(w.dualWieldWeapon) && w.dualWieldWeapon != level.weaponNone)
					self SetWeaponAmmoClip(w.dualWieldWeapon, w.dualWieldWeapon.clipSize);
			}
			foreach(weap in self GetWeaponsList(true))
				self GiveMaxAmmo(weap);
			wait 0.1;
		}
	}
	else
	{
		self notify("mm_ammo_off");
		self mm_msg("Infinite Ammo ^1OFF");
	}
}

function tog_notarget(arg)
{
	if(self mm_toggle("notarget"))
	{
		self zm_utility::increment_ignoreme();
		self mm_msg("Zombies Ignore Me ^2ON");
	}
	else
	{
		self zm_utility::decrement_ignoreme();
		self mm_msg("Zombies Ignore Me ^1OFF");
	}
}

function tog_ufo(arg)
{
	if(self mm_toggle("ufo"))
	{
		self mm_msg("UFO Mode ^2ON ^7- close the menu, hold ^3[{+attack}] ^7to fly");
		self endon("disconnect");
		self endon("mm_ufo_off");

		self.mm_ufo_ent = Spawn("script_origin", self.origin);
		self.mm_ufo_ent.angles = self.angles;
		self PlayerLinkTo(self.mm_ufo_ent);
		self DisableWeapons();

		for(;;)
		{
			if(!self.mm_open && self AttackButtonPressed())
			{
				dir = AnglesToForward(self GetPlayerAngles());
				self.mm_ufo_ent.origin = self.mm_ufo_ent.origin + (dir * 40);
			}
			wait 0.05;
		}
	}
	else
	{
		self notify("mm_ufo_off");
		self Unlink();
		if(isdefined(self.mm_ufo_ent))
			self.mm_ufo_ent Delete();
		self.mm_ufo_ent = undefined;
		if(!self.mm_open)
			self EnableWeapons();
		self mm_msg("UFO Mode ^1OFF");
	}
}

function tog_specialist(arg)
{
	if(self mm_toggle("specialist"))
	{
		self mm_msg("Infinite Specialist ^2ON");
		self endon("disconnect");
		self endon("mm_specialist_off");
		for(;;)
		{
			self GadgetPowerSet(0, 100);
			wait 0.2;
		}
	}
	else
	{
		self notify("mm_specialist_off");
		self mm_msg("Infinite Specialist ^1OFF");
	}
}

function give_points(amount)
{
	self zm_score::add_to_player_score(amount);
	self mm_msg("^2Points added");
}

function refill_health(arg)
{
	self.health = self.maxhealth;
	self mm_msg("Health refilled");
}

// ---------------------------------------------------------------------------
// Weapons
// ---------------------------------------------------------------------------

function pap_current(arg)
{
	w = self GetCurrentWeapon();
	if(!zm_weapons::can_upgrade_weapon(w))
	{
		self mm_msg("^1This weapon can't be Pack-a-Punched");
		return;
	}
	upgraded = zm_weapons::get_upgrade_weapon(w);
	self TakeWeapon(w);
	self zm_weapons::weapon_give(upgraded, 1, 0, 1, 1);
	self mm_msg("^2Weapon Pack-a-Punched");
}

function max_ammo_all(arg)
{
	foreach(w in self GetWeaponsList(true))
	{
		self GiveMaxAmmo(w);
		self SetWeaponAmmoClip(w, w.clipSize);
	}
	self mm_msg("Max ammo given");
}

function take_current(arg)
{
	w = self GetCurrentWeapon();
	if(w == level.weaponNone)
		return;
	self zm_weapons::weapon_take(w);
	self mm_msg("Weapon taken");
}

function give_weapon(w)
{
	self zm_weapons::weapon_give(w, 0, 0, 0, 1);
	self mm_msg("Gave ^3" + weapon_label(w));
}

function weapon_label(w)
{
	label = MakeLocalizedString(w.displayName);
	if(!isdefined(label) || label == "")
		label = w.name;
	return label;
}

// ---------------------------------------------------------------------------
// Perks
// ---------------------------------------------------------------------------

function give_all_perks(arg)
{
	self zm_utility::give_player_all_perks();
	self mm_msg("^2All perks given");
}

function give_one_perk(perk)
{
	if(self HasPerk(perk))
	{
		self mm_msg("You already have " + perk_name(perk));
		return;
	}
	self zm_perks::give_perk(perk, 0);
	self mm_msg("Gave " + perk_name(perk));
}

function remove_all_perks(arg)
{
	if(!isdefined(level._custom_perks))
		return;
	foreach(perk in GetArrayKeys(level._custom_perks))
	{
		if(self HasPerk(perk))
			self notify(perk + "_stop");
	}
	self mm_msg("Perks removed");
}

function perk_name(perk)
{
	switch(perk)
	{
		case "specialty_armorvest": return "Juggernog";
		case "specialty_quickrevive": return "Quick Revive";
		case "specialty_doubletap2": return "Double Tap";
		case "specialty_staminup": return "Stamin-Up";
		case "specialty_fastreload": return "Speed Cola";
		case "specialty_additionalprimaryweapon": return "Mule Kick";
		case "specialty_deadshot": return "Deadshot Daiquiri";
		case "specialty_widowswine": return "Widow's Wine";
		case "specialty_electriccherry": return "Electric Cherry";
		case "specialty_phdflopper": return "PhD Flopper";
	}
	return perk;
}

// ---------------------------------------------------------------------------
// Power-ups
// ---------------------------------------------------------------------------

function spawn_powerup(name)
{
	angles = self GetPlayerAngles();
	pos = self.origin + (AnglesToForward((0, angles[1], 0)) * 90);
	zm_powerups::specific_powerup_drop(name, pos);
	self mm_msg("Spawned " + powerup_name(name));
}

function powerup_name(p)
{
	switch(p)
	{
		case "nuke": return "Nuke";
		case "insta_kill": return "Insta-Kill";
		case "double_points": return "Double Points";
		case "full_ammo": return "Max Ammo";
		case "carpenter": return "Carpenter";
		case "fire_sale": return "Fire Sale";
		case "minigun": return "Death Machine";
		case "free_perk": return "Free Perk";
		case "bonus_points_player": return "Bonus Points (player)";
		case "bonus_points_team": return "Bonus Points (team)";
		case "shield_charge": return "Shield Charge";
		case "ww_grenade": return "Widow's Wine Grenade";
	}
	return p;
}

// ---------------------------------------------------------------------------
// Zombies & rounds
// ---------------------------------------------------------------------------

function kill_all_zombies(arg)
{
	zombies = GetAITeamArray(level.zombie_team);
	count = 0;
	foreach(z in zombies)
	{
		if(isdefined(z) && IsAlive(z))
		{
			z DoDamage(z.health + 666, z.origin, self);
			count++;
		}
	}
	self mm_msg("Killed ^3" + count + " ^7zombies");
}

function tog_onehit(arg)
{
	if(self mm_toggle("onehit"))
	{
		self mm_msg("One-Hit Kills ^2ON");
		self endon("disconnect");
		self endon("mm_onehit_off");
		for(;;)
		{
			foreach(z in GetAITeamArray(level.zombie_team))
			{
				if(isdefined(z) && IsAlive(z) && z.health > 1)
					z.health = 1;
			}
			wait 0.25;
		}
	}
	else
	{
		self notify("mm_onehit_off");
		self mm_msg("One-Hit Kills ^1OFF");
	}
}

function round_skip(delta)
{
	self round_goto(level.round_number + delta);
}

function round_goto(n)
{
	if(n < 1)
		n = 1;
	self mm_msg("Going to round ^3" + n);
	level thread zm_utility::zombie_goto_round(n);
}

// ---------------------------------------------------------------------------
// Map
// ---------------------------------------------------------------------------

function open_all_doors(arg)
{
	// Same approach as the game's own dev command: unlock_all makes the door
	// scripts skip the cost check, and a forced trigger opens each one.
	SetDvar("zombie_unlock_all", 1);

	names = array("zombie_door", "zombie_airlock_buy", "zombie_debris");
	foreach(name in names)
	{
		ents = GetEntArray(name, "targetname");
		foreach(ent in ents)
		{
			if(isdefined(ent))
				ent notify("trigger", self, true);
			wait 0.05;
		}
	}

	wait 1;
	SetDvar("zombie_unlock_all", 0);
	self mm_msg("^2All doors & debris opened");
}

function power_on(arg)
{
	found = false;
	foreach(name in array("use_elec_switch", "use_power_switch", "use_master_switch"))
	{
		trig = GetEnt(name, "targetname");
		if(isdefined(trig))
		{
			trig notify("trigger", self);
			found = true;
		}
	}

	if(!found)
	{
		// Maps with multiple generators use numbered flags
		for(i = 1; i < 10; i++)
		{
			if(level flag::exists("power_on" + i))
				level flag::set("power_on" + i);
		}
		if(level flag::exists("power_on"))
			level flag::set("power_on");
		if(level flag::exists("all_power_on"))
			level flag::set("all_power_on");
	}

	self mm_msg("Power turned on (map support varies)");
}

function end_game(arg)
{
	self mm_close_menu();
	level notify("end_game");
}

// ---------------------------------------------------------------------------
// Teleport
// ---------------------------------------------------------------------------

function tp_save(arg)
{
	self.mm_saved_pos = self.origin;
	self.mm_saved_ang = self GetPlayerAngles();
	self mm_msg("Position saved");
}

function tp_load(arg)
{
	if(!isdefined(self.mm_saved_pos))
	{
		self mm_msg("^1No saved position");
		return;
	}
	self mm_teleport(self.mm_saved_pos);
	self SetPlayerAngles(self.mm_saved_ang);
	self mm_msg("Position loaded");
}

function tp_crosshair(arg)
{
	eye = self GetEye();
	dir = AnglesToForward(self GetPlayerAngles());
	trace = BulletTrace(eye, eye + (dir * 10000), false, self);
	pos = trace["position"] - (dir * 25);
	self mm_teleport(pos);
	self mm_msg("Teleported");
}

function mm_teleport(pos)
{
	if(isdefined(self.mm_ufo_ent))
		self.mm_ufo_ent.origin = pos;
	else
		self SetOrigin(pos);
}

// ---------------------------------------------------------------------------
// Fun
// ---------------------------------------------------------------------------

function tog_thirdperson(arg)
{
	if(self mm_toggle("thirdperson"))
	{
		self SetClientThirdPerson(1);
		self mm_msg("Third Person ^2ON");
	}
	else
	{
		self SetClientThirdPerson(0);
		self mm_msg("Third Person ^1OFF");
	}
}

function tog_speed(arg)
{
	if(self mm_toggle("speed"))
	{
		self SetMoveSpeedScale(2);
		self mm_msg("Super Speed ^2ON");
	}
	else
	{
		self SetMoveSpeedScale(1);
		self mm_msg("Super Speed ^1OFF");
	}
}
