using System;

namespace MOD_h6Zv8g.DualWield
{
    internal static class DualWieldLoadoutGuard
    {
        public static bool PromoteSavedOffhandToMain(string reason, bool logNoSaved)
        {
            try
            {
                if (g.world == null || g.world.playerUnit == null || g.world.playerUnit.data == null || g.world.playerUnit.data.unitData == null)
                {
                    return false;
                }

                var unitData = g.world.playerUnit.data.unitData;
                if (!string.IsNullOrEmpty(unitData.skillLeft))
                {
                    return false;
                }

                DualWieldSaveStore.EnsureLoaded();
                string selectedOffhandSkillId = DualWieldSaveStore.OffhandSkillId;
                if (string.IsNullOrEmpty(selectedOffhandSkillId))
                {
                    if (logNoSaved)
                    {
                        DualWieldLog.Info("Offhand skipped: no main normal attack and no saved offhand selected.", false);
                    }
                    return false;
                }

                var allMartial = unitData.allActionMartial;
                if (allMartial == null || !allMartial.ContainsKey(selectedOffhandSkillId))
                {
                    DualWieldLog.Info("Offhand promote skipped: saved offhand skill not found in allActionMartial: " + selectedOffhandSkillId, true);
                    DualWieldSaveStore.ClearOffhandSkillId("promote-saved-skill-missing-" + reason);
                    return false;
                }

                unitData.skillLeft = selectedOffhandSkillId;
                g.world.playerUnit.CreateAction(new UnitActionMartialEquip(allMartial[selectedOffhandSkillId], 0), false);
                DualWieldSaveStore.ClearOffhandSkillId("promote-offhand-to-main-" + reason);
                DualWieldLog.Info("Offhand promoted to main normal attack and offhand cleared. skillId=" + selectedOffhandSkillId + ", reason=" + reason, true);
                return true;
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("Offhand promote to main failed: " + ex, true);
                return false;
            }
        }
    }
}
