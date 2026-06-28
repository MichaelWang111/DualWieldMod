using System;

namespace MOD_h6Zv8g.DualWield
{
    internal static class DualWieldSaveStore
    {
        private const string SaveGroup = "MOD_h6Zv8g.DualWield";
        private const string SchemaVersionKey = "schemaVersion";
        private const string OffhandSkillIdKey = "offhandSkillId";
        private const string CurrentSchemaVersion = "1";

        private static string offhandSkillId = string.Empty;
        private static bool hasLoaded;

        public static string OffhandSkillId
        {
            get { return offhandSkillId; }
        }

        public static void ResetSession()
        {
            offhandSkillId = string.Empty;
            hasLoaded = false;
        }

        public static void Load()
        {
            try
            {
                offhandSkillId = string.Empty;

                if (g.data.obj.ContainsKey(SaveGroup, OffhandSkillIdKey))
                {
                    offhandSkillId = g.data.obj.GetString(SaveGroup, OffhandSkillIdKey) ?? string.Empty;
                }

                hasLoaded = true;
                DualWieldLog.Info("Save loaded. version=" + ReadSchemaVersion() + ", offhandSkillId=" + FormatSkillId(offhandSkillId), true);
            }
            catch (Exception ex)
            {
                hasLoaded = false;
                offhandSkillId = string.Empty;
                DualWieldLog.Info("Save load failed: " + ex, true);
            }
        }

        public static void EnsureLoaded()
        {
            if (!hasLoaded)
            {
                Load();
            }
        }

        public static void Save()
        {
            try
            {
                g.data.obj.SetString(SaveGroup, SchemaVersionKey, CurrentSchemaVersion);
                g.data.obj.SetString(SaveGroup, OffhandSkillIdKey, offhandSkillId ?? string.Empty);
                DualWieldLog.Info("Save written. version=" + CurrentSchemaVersion + ", offhandSkillId=" + FormatSkillId(offhandSkillId), true);
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("Save write failed: " + ex, true);
            }
        }

        public static void SetOffhandSkillId(string skillId, string reason)
        {
            string nextSkillId = skillId ?? string.Empty;
            if (offhandSkillId == nextSkillId)
            {
                return;
            }

            offhandSkillId = nextSkillId;
            DualWieldLog.Info("Offhand save updated. skillId=" + FormatSkillId(offhandSkillId) + ", reason=" + reason, true);
            Save();
        }

        public static void ClearOffhandSkillId(string reason)
        {
            SetOffhandSkillId(string.Empty, reason);
        }

        private static string ReadSchemaVersion()
        {
            if (!g.data.obj.ContainsKey(SaveGroup, SchemaVersionKey))
            {
                return "none";
            }

            return g.data.obj.GetString(SaveGroup, SchemaVersionKey) ?? "none";
        }

        private static string FormatSkillId(string skillId)
        {
            return string.IsNullOrEmpty(skillId) ? "<empty>" : skillId;
        }
    }
}
