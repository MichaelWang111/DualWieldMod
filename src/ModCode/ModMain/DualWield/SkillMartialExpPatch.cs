using HarmonyLib;

namespace MOD_h6Zv8g.DualWield
{
    [HarmonyPatch(typeof(UnitCtrlPlayer), nameof(UnitCtrlPlayer.AddSkillMartialExp), new[] { typeof(string), typeof(int), typeof(float) })]
    internal static class SkillMartialExpStringPatch
    {
        private static bool Prefix(UnitCtrlPlayer __instance, string martialID, int talent, float growExp)
        {
            return !DualWieldAttributionGuard.ShouldSkipMainMartialExp(__instance, martialID, null, talent, growExp, "string");
        }
    }

    [HarmonyPatch(typeof(UnitCtrlPlayer), nameof(UnitCtrlPlayer.AddSkillMartialExp), new[] { typeof(DataUnit.ActionMartialData), typeof(int), typeof(float) })]
    internal static class SkillMartialExpActionDataPatch
    {
        private static bool Prefix(UnitCtrlPlayer __instance, DataUnit.ActionMartialData actionMartialData, int talent, float growExp)
        {
            return !DualWieldAttributionGuard.ShouldSkipMainMartialExp(__instance, null, actionMartialData, talent, growExp, "actionData");
        }
    }
}
