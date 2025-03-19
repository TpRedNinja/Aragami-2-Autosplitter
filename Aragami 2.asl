state("Aragami2")
{
    int AbilityPoints: "GameAssembly.dll", 0x042DBC10, 0xBC8, 0x3F8, 0x6C;
}

startup
{
    //made by ero
    // TextComponent stuff.
    var lcCache = new Dictionary<string, LiveSplit.UI.Components.ILayoutComponent>();
    vars.SetTextComponent = (Action<string, string, object>)((key, text1, text2) =>
    {
        LiveSplit.UI.Components.ILayoutComponent lc;
        if (!lcCache.TryGetValue(key, out lc))
        {
            lc = timer.Layout.LayoutComponents.Cast<dynamic>()
                .FirstOrDefault(llc => Path.GetFileName(llc.Path) == "LiveSplit.Text.dll" && llc.Component.Settings.Text1 == text1)
                ?? LiveSplit.UI.Components.ComponentManager.LoadLayoutComponent("LiveSplit.Text.dll", timer);

            lcCache.Add(key, lc);
        }

        if (!timer.Layout.LayoutComponents.Contains(lc))
            timer.Layout.LayoutComponents.Add(lc);

        dynamic tc = lc.Component;
        tc.Settings.Text1 = text1;
        tc.Settings.Text2 = text2.ToString();
    });

    vars.RemoveTextComponent = (Action<string>)(key =>
    {
        LiveSplit.UI.Components.ILayoutComponent lc;
        if (lcCache.TryGetValue(key, out lc))
        {
            timer.Layout.LayoutComponents.Remove(lc);
            lcCache.Remove(key);
        }
    });

    vars.RemoveAllTextComponents = (Action)(() =>
    {
        foreach (var lc in lcCache.Values)
            timer.Layout.LayoutComponents.Remove(lc);

        lcCache.Clear();
    });

   // asl-help
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.GameName = "Aragami 2";
    //vars.Helper.AlertGameTime();

    // Settings.
    settings.Add("splits", true, "Splits");
        settings.Add("BaseSplits", false, "BaseSplits", "splits");
        settings.Add("MissionsSplits", false, "BaseSplits", "splits");
        settings.Add("FinalSplit", false, "FinalSplit", "splits");

    settings.Add("igt", false, "In-Game Time");
        settings.Add("igt-session", false, "igt-session", "igt");
        settings.SetToolTip("igt-session", "Use for any% ng runs");

    settings.Add("texts", false, "Text Displays");
        settings.Add("texts-missions", false, "Show completed missions", "texts");
        settings.Add("texts-misc", false, "Show misc", "texts");
            settings.Add("texts-kills", false, "Show total kills", "texts-misc");
            settings.Add("texts-ability-points", false, "Show ability points", "texts-misc");
            settings.Add("texts-player-level", false, "Show player level", "texts-misc");
            settings.Add("texts-experience", false, "Show experience", "texts-misc");
        settings.Add("texts-menus-bools", false, "Show menu bools", "texts");
            settings.Add("settings-menu", true, "Show settings menu bool", "texts-menus-bools");
            settings.Add("main-menu", true, "Show main menu bool", "texts-menus-bools");
            settings.Add("pause-menu", true, "Show pause menu bool", "texts-menus-bools");
        settings.Add("texts-remove", true, "Remove all texts on exit", "texts");

    // Data.
    vars.SceneId_Hub = false;
    vars.InMission = false;

    vars.AllMissionIds = new[]
    {
        00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
        31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51
    };

    vars.LevelThreshHolds = new[]
    {
        100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500, 5500, 6600, 7800, 9100, 10500, 12000, 13600, 15300, 17100, 19000, 
        21000, 23100, 25300, 27600
    };

    vars.IncompleteMissions = new HashSet<int>(vars.AllMissionIds);
    vars.LevelsNotAchieved = new HashSet<int>(vars.LevelThreshHolds);

    vars.OnEndCutscene = false;
    vars.TotalIgt = 0f;
    vars.TotalAbilityPoints = 0;
    vars.PlayerLevel = 0;
    vars.menuList = new List<int>();
    vars.PauseMenuOpen = false;
    vars.MainMenuOpen1 = false;
    vars.SettingsMenuOpen = false;
    vars.MainMenuOpen = false;

    // Helper functions.
    vars.LogChange = (Action<string>)(key =>
    {
        if (vars.Helper[key].Changed)
        {
            vars.Log(key + ": " + vars.Helper[key].Old + " -> " + vars.Helper[key].Current);
        }
    });
}

init
{
    vars.ShowTextIfEnabled = (Action<string, string, object>)((key, text1, text2) =>
    {
        if (settings[key])
        {
            vars.SetTextComponent(key, text1, text2);
        }
        else if (settings["texts-remove"])
        {
            vars.RemoveTextComponent(key);
        }
    });

    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
    {
        var mm = mono["MissionManager", 1];
        vars.Helper["IsCinematic"] = mm.Make<bool>("m_Instance", mm["m_CinematicRunning"]);
        vars.Helper["MissionState"] = mm.Make<int>("m_Instance", mm["missionState"]);
        
        var ms = mono["MissionStatus"];
        //values being used
        vars.Helper["MissionId"] = mm.Make<int>("m_Instance", "currentMissionStatus", ms["id"]);
        vars.Helper["MissionRank"] = mm.Make<int>("m_Instance", "currentMissionStatus", ms["rank"]);
        vars.Helper["MissionTime"] = mm.Make<float>("m_Instance", "currentMissionStatus", ms["timePlayed"]);
            //values being used for text display
            vars.Helper["hostilesKilled"] = mm.Make<int>("m_Instance", "currentMissionStatus", ms["hostilesKilled"]);
            vars.Helper["totalHostiles"] = mm.Make<int>("m_Instance", "currentMissionStatus", ms["totalHostiles"]);
            //values not being used but keeping anyways
            vars.Helper["XP"] = mm.Make<int>("m_Instance", "currentMissionStatus", ms["currentPlayerExperience"]);
            vars.Helper["Gold"] = mm.Make<int>("m_Instance", "currentMissionStatus", ms["currentGold"]);
        
        var gm = mono["GameManager", 1];
        vars.Helper["SessionTime"] = gm.Make<float>("m_Instance", gm["_sessionTime"]);

        var SceneLoader = mono["SceneLoader", 1];
        vars.Helper["Scene"] = SceneLoader.Make<int>("m_Instance", SceneLoader["loadingCurrentSceneNumber"]);

        var MM = mono["MenuManager", 1];
        vars.Helper["Menus"] = MM.MakeList<IntPtr>("m_Instance", "m_MenuStack");
        int subMenuTypeOffset = mono["SubMenu"]["menuType"];
        vars.GetOpenMenuTypes = (Func<List<int>>)(() => ((List<IntPtr>)current.Menus).Select(menu => game.ReadValue<int>(menu + subMenuTypeOffset)).ToList());
        


        //extra stuff not being used keeping anyways
        /*v
        var Location = mono["MissionLocation"];
        var CinematicsManager = mono["CinematicsManager"];
        
        var CinematicBase = mono["CinematicBase"];
        var UI = mono["UIMapLocation"];*/
        return true;
    });
}

update
{
    vars.ShowTextIfEnabled("texts-missions", "Missions", Math.Max(51 - vars.IncompleteMissions.Count, 0) + "/51");
    vars.ShowTextIfEnabled("texts-kills","Total Kills: ", current.hostilesKilled + "/" + current.totalHostiles);
    vars.ShowTextIfEnabled("texts-experience", "Current Experience: ", current.XP);

    if (current.AbilityPoints == old.AbilityPoints + 1)
    {
        vars.TotalAbilityPoints ++;
    }
    vars.ShowTextIfEnabled("texts-ability-points", "Current AbiltyPoints: ", current.AbilityPoints + "/" + vars.TotalAbilityPoints);
    
    var enumerator = vars.LevelsNotAchieved.GetEnumerator();
    List<int> itemsToRemove = new List<int>();  // Create the local list to track removals

    // Iterate over the HashSet using the enumerator
    while (enumerator.MoveNext())
    {
        int num = enumerator.Current;
        if (current.XP > num)
        {
            vars.PlayerLevel++;
            itemsToRemove.Add(num);  // Mark the item for removal
        }
    }

    // After the loop, remove the items from the HashSet
    foreach (var num in itemsToRemove)
    {
        vars.LevelsNotAchieved.Remove(num);  // Remove the items safely
    }
    vars.ShowTextIfEnabled("texts-player-level", "Player Level:", vars.PlayerLevel);
    
    var menus = vars.GetOpenMenuTypes();
    vars.MainMenuOpen1 = menus.Contains(0); // Menus.MainMenu 
    vars.PauseMenuOpen = menus.Contains(7); // Menus.PauseMenu
    vars.SettingsMenuOpen = menus.Contains(10); // Menus.SettingsMenu
    vars.EndMissionMenuOpen = menus.Contains(8); // Menus.EndMissionMenu
    vars.ShowTextIfEnabled("main-menu", "Main Menu: ", vars.MainMenuOpen);
    vars.ShowTextIfEnabled("pause-menu", "Pause Menu: ", vars.PauseMenuOpen);
    vars.ShowTextIfEnabled("settings-menu", "Settings Menu: ", vars.SettingsMenuOpen);
    vars.ShowTextIfEnabled("texts-menus-bools", "SceneId_Hub", vars.SceneId_Hub);

    for (int i = 0; i < menus.Count; i++)
    {
        if (!vars.menuList.Contains(menus[i]))
        {
            vars.menuList.Add(menus[i]);
            vars.menuList.Sort();
            print("Menus: " + string.Join(", ", vars.menuList));
        }
    }

    if (vars.MainMenuOpen1 == true && current.Scene == 0)
    {
        vars.MainMenuOpen = true;
    } else
    {
        vars.MainMenuOpen = false;
    }

    if (current.Scene == 3 && current.MissionTime == 0 && current.MissionTime == old.MissionTime && current.MissionState == 2 && !current.IsCinematic 
    && current.MissionId == -1)
    {
        vars.SceneId_Hub = true;
        vars.InMission = false;
    } else
    {
        vars.SceneId_Hub = false;
        vars.InMission = true;
    }

    //print("Menus: " + current.MissionRank);
    
    //print("current.MissionState: " + current.MissionState);
    //print("current pausemenu: " + vars.PauseMenuOpen.ToString());

    //what each number is
    /*0-main menu, ability tree
    1-Blacksmith
    7-pause menu
    8-end screen menu
    10-settings menu
    11-browser menu
    12-danjuro
    13-mission selection menu
    14-control mapping
    16-tutorials*/
}

start
{
    //Starts ideally after you skip the first cutscene
    //return old.MissionTime == 0f && current.MissionTime > 0f && current.Scene == 5; 
    if (current.Scene == 5 && old.MissionTime == 0f && current.MissionTime > 0f)
    {
        return true;
    }
}

onStart
{
    //adds all the missions id's to a incompleted missions list
    vars.IncompleteMissions = new HashSet<int>(vars.AllMissionIds);
}

split
{
    if (settings["BaseSplits"])
    {
        // Leave hub.
        if (vars.SceneId_Hub == false && vars.InMission == true && current.Scene == 0 && old.Scene != 0)
        {
            return true;
        }
    }
    
    if (settings["MissionsSplits"])
    {
        // Complete missions.
        if (old.MissionRank == 0 && current.MissionRank > 0 && current.MissionState == 4 && vars.IncompleteMissions.Remove(current.MissionId)) // Must not yet be completed.
        {
            vars.menuList.Clear();
            return true;
        }
    }

    if (settings["FinalSplit"])
    {
        // End cutscene.
        if (vars.IncompleteMissions.Count == 0 // If no more missions remain.
            && !old.IsCinematic && current.IsCinematic) // Cutscene starts.
        {
            vars.OnEndCutscene = true;
        }

        if (vars.OnEndCutscene && old.IsCinematic && !current.IsCinematic)
        {
            return true;
        }
    }    
    
}

gameTime
{
    /*
    Times i want to use the igt timer instead of session time
    -when in a level so when current.MissionTime > old.MissionTime
    -when when a cutscene is playing so when current.IsCinematic is true
    -when in a loading screen so when missionstate == 1
    -when showing the end screen so when vars.EndMissionMenuOpen == true

    Times i want to use the session timer instead of game time
    -when in the hub so when current.Scene == vars.SceneId_Hub
    -when in the pause menu so when vars.PauseMenuOpen == true
    */

    if (settings["igt-session"] && vars.SceneId_Hub || vars.PauseMenuOpen) // Or in pause menu.
    {
        vars.TotalIgt += current.SessionTime - old.SessionTime;
    } else
    {
        //so it doesnt go to a negative number
        if (current.MissionTime - old.MissionTime < 0)
            {
                vars.TotalIgt += current.MissionTime + old.MissionTime;
            }
            vars.TotalIgt += current.MissionTime - old.MissionTime; // Count the level time in all other cases.
    }

    return TimeSpan.FromSeconds(vars.TotalIgt);
}

reset
{
    return vars.MainMenuOpen;
}

onReset
{
    vars.TotalIgt = 0f;
    vars.PlayerLevel = 0;

    if (vars.LevelsNotAchieved.Count > 0)
    {
        vars.LevelsNotAchieved.Clear();
        vars.LevelsNotAchieved = new HashSet<int>(vars.LevelThreshHolds);
    }

}

isLoading
{
    return true;
}

exit
{
    if (settings["texts-remove"])
    {
        vars.RemoveAllTextComponents();
    }
        
    if (vars.LevelsNotAchieved.Count > 0)
    {
        vars.LevelsNotAchieved.Clear();
        vars.LevelsNotAchieved = new HashSet<int>(vars.LevelThreshHolds);
    }
}

shutdown
{
    if (settings["texts-remove"])
    {
        vars.RemoveAllTextComponents();
    }
    
    if (vars.LevelsNotAchieved.Count > 0)
    {
        vars.LevelsNotAchieved.Clear();
        vars.LevelsNotAchieved = new HashSet<int>(vars.LevelThreshHolds);
    }
}

/*
Notes:

level thresholds:
    lvl 0-0-0
    lvl 1-100-100
    lvl 2-300-200
    lvl 3-600-300
    lvl 4-1000-400
    lvl 5-1500-500
    lvl 6-2100-600
    lvl 7-2800-700
    lvl 8-3600-800
    lvl 9-4500-900
    lvl 10-5500-1000
    lvl 11-6600-1100
    lvl 12-7800-1200
    lvl 13-9100-1300
    lvl 14-10500-1400
    lvl 15-12000-1500
    lvl 16-13600-1600
    lvl 17-15300-1700
    lvl 18-17100-1800
    lvl 19-19000-1900
    lvl 20-21000-2000
    lvl 21-23100-2100
    lvl 22-25300-2200
    lvl 23-27600-2300
    lvl 24-30000-2400
    lvl 25-32500-2500


*/
