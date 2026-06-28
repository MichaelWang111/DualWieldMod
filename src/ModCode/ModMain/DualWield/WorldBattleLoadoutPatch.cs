using System;
using System.Collections.Generic;
using System.Reflection;
using HarmonyLib;

namespace MOD_h6Zv8g.DualWield
{
    [HarmonyPatch]
    internal static class WorldBattleLoadoutPatch
    {
        private static IEnumerable<MethodBase> TargetMethods()
        {
            foreach (MethodInfo method in AccessTools.GetDeclaredMethods(typeof(WorldBattleMgr)))
            {
                if (method.Name == "IntoBattle")
                {
                    yield return method;
                }
            }
        }

        private static void Prefix()
        {
            try
            {
                DualWieldLoadoutGuard.PromoteSavedOffhandToMain("world-battle-prefix", false);
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("WorldBattle loadout guard failed: " + ex, true);
            }
        }
    }
}
