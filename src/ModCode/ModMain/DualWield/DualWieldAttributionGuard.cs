using System;
using UnityEngine;
using UnhollowerBaseLib;

namespace MOD_h6Zv8g.DualWield
{
    internal static class DualWieldAttributionGuard
    {
        private const float QueueProtectSeconds = 0.20f;
        private const float CreateProtectSeconds = 0.20f;
        private const float HitProtectSeconds = 0.45f;
        private const float RestoreDelaySeconds = 0.08f;
        private const float RestoreWindowSeconds = 0.80f;
        private const float MainHitGraceSeconds = 0.35f;
        private const int BlockLogLimit = 12;
        private const int RollbackLogLimit = 12;

        private static bool active;
        private static UnitCtrlPlayer player;
        private static string mainSkillId = string.Empty;
        private static string offhandSkillId = string.Empty;
        private static DataUnit.ActionMartialData mainMartial;
        private static DataUnit.ActionMartialData offhandMartial;
        private static int offhandCreateDepth;
        private static float blockMainExpUntil;
        private static string blockReason = string.Empty;
        private static int blockedMainExpCount;
        private static int rollbackMainExpCount;
        private static bool hasMainBaseline;
        private static int mainBaselineExp;
        private static float mainBaselineUseAddExp;
        private static bool mainBaselineUseAddExpExists;
        private static bool rollbackPending;
        private static float rollbackAt;
        private static float rollbackUntil;
        private static string rollbackReason = string.Empty;
        private static float mainHitGraceUntil;

        public static void Configure(UnitCtrlPlayer owner, string mainId, DataUnit.ActionMartialData mainData, string offhandId, DataUnit.ActionMartialData offhandData)
        {
            player = owner;
            mainSkillId = mainId ?? string.Empty;
            offhandSkillId = offhandId ?? string.Empty;
            mainMartial = mainData;
            offhandMartial = offhandData;
            offhandCreateDepth = 0;
            blockMainExpUntil = 0f;
            blockReason = string.Empty;
            blockedMainExpCount = 0;
            rollbackMainExpCount = 0;
            hasMainBaseline = false;
            mainBaselineExp = 0;
            mainBaselineUseAddExp = 0f;
            mainBaselineUseAddExpExists = false;
            rollbackPending = false;
            rollbackAt = 0f;
            rollbackUntil = 0f;
            rollbackReason = string.Empty;
            mainHitGraceUntil = 0f;
            active = !string.IsNullOrEmpty(mainSkillId) && !string.IsNullOrEmpty(offhandSkillId) && mainSkillId != offhandSkillId;

            if (active)
            {
                RefreshMainBaseline("configure");
                DualWieldLog.Info("DWT-024 attribution guard armed. mainSkillId=" + mainSkillId + ", offhandSkillId=" + offhandSkillId, false);
            }
        }

        public static void Clear(string reason)
        {
            if (active && (blockedMainExpCount > 0 || rollbackMainExpCount > 0))
            {
                DualWieldLog.Info("DWT-024 exp guard summary. reason=" + reason + ", blockedMainExp=" + blockedMainExpCount + ", rollbackMainExp=" + rollbackMainExpCount + ", mainSkillId=" + mainSkillId + ", offhandSkillId=" + offhandSkillId, false);
            }

            active = false;
            player = null;
            mainSkillId = string.Empty;
            offhandSkillId = string.Empty;
            mainMartial = null;
            offhandMartial = null;
            offhandCreateDepth = 0;
            blockMainExpUntil = 0f;
            blockReason = string.Empty;
            blockedMainExpCount = 0;
            rollbackMainExpCount = 0;
            hasMainBaseline = false;
            mainBaselineExp = 0;
            mainBaselineUseAddExp = 0f;
            mainBaselineUseAddExpExists = false;
            rollbackPending = false;
            rollbackAt = 0f;
            rollbackUntil = 0f;
            rollbackReason = string.Empty;
            mainHitGraceUntil = 0f;
        }

        public static void MarkOffhandQueued(int queueCount)
        {
            CaptureMainBaselineIfIdle("queue#" + queueCount);
            ExtendBlockWindow(QueueProtectSeconds, "queue#" + queueCount);
        }

        public static void BeginOffhandCreate(int fireIndex)
        {
            offhandCreateDepth++;
            CaptureMainBaselineIfIdle("create#" + fireIndex);
            ExtendBlockWindow(CreateProtectSeconds, "create#" + fireIndex);
        }

        public static void EndOffhandCreate()
        {
            if (offhandCreateDepth > 0)
            {
                offhandCreateDepth--;
            }
        }

        public static void MarkOffhandFired(int fireIndex)
        {
            ExtendBlockWindow(CreateProtectSeconds, "fired#" + fireIndex);
        }

        public static void MarkPotentialOffhandHit(string reason)
        {
            ExtendBlockWindow(HitProtectSeconds, "hit:" + reason);
            ScheduleRollback("hit:" + reason);
        }

        public static void MarkMainHit(string reason)
        {
            if (!active)
            {
                return;
            }

            mainHitGraceUntil = Time.time + MainHitGraceSeconds;
            rollbackPending = false;
            RefreshMainBaseline("main-hit:" + reason);
        }

        public static void Tick(string source)
        {
            try
            {
                if (!active)
                {
                    return;
                }

                if (Time.time <= mainHitGraceUntil)
                {
                    RefreshMainBaseline("main-hit-grace:" + source);
                    return;
                }

                if (!rollbackPending)
                {
                    if (!IsProtectionWindowActive())
                    {
                        RefreshMainBaseline("idle:" + source);
                    }
                    return;
                }

                if (Time.time > rollbackUntil)
                {
                    rollbackPending = false;
                    RefreshMainBaseline("rollback-window-ended:" + source);
                    return;
                }

                if (Time.time < rollbackAt)
                {
                    return;
                }

                RollbackMainStateIfChanged(source);
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("DWT-024 exp guard tick failed open: " + ex.Message, false);
            }
        }

        public static bool ShouldSkipMainMartialExp(UnitCtrlPlayer owner, string martialId, DataUnit.ActionMartialData martialData, int talent, float growExp, string overload)
        {
            try
            {
                if (!active || growExp <= 0f || !IsProtectionWindowActive() || Time.time <= mainHitGraceUntil)
                {
                    return false;
                }

                if (!IsSamePlayer(owner))
                {
                    return false;
                }

                if (IsOffhandTarget(martialId, martialData))
                {
                    return false;
                }

                if (!IsMainTarget(martialId, martialData))
                {
                    return false;
                }

                ScheduleRollback("blocked:" + overload);
                blockedMainExpCount++;
                if (blockedMainExpCount <= BlockLogLimit)
                {
                    DualWieldLog.Info("DWT-024 blocked main exp during offhand window. count=" + blockedMainExpCount + ", overload=" + overload + ", target=" + DescribeTarget(martialId, martialData) + ", talent=" + talent + ", growExp=" + growExp.ToString("0.###") + ", reason=" + blockReason + ", remaining=" + FormatRemainingSeconds(), false);
                }

                return true;
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("DWT-024 exp guard failed open: " + ex.Message, false);
                return false;
            }
        }

        private static void ScheduleRollback(string reason)
        {
            if (!active || Time.time <= mainHitGraceUntil)
            {
                return;
            }

            if (!hasMainBaseline)
            {
                RefreshMainBaseline("schedule:" + reason);
            }

            rollbackPending = true;
            float newRollbackAt = Time.time + RestoreDelaySeconds;
            if (rollbackAt <= 0f || newRollbackAt < rollbackAt || Time.time > rollbackUntil)
            {
                rollbackAt = newRollbackAt;
            }

            float newRollbackUntil = Time.time + RestoreWindowSeconds;
            if (newRollbackUntil > rollbackUntil)
            {
                rollbackUntil = newRollbackUntil;
            }

            rollbackReason = reason ?? string.Empty;
        }

        private static void ExtendBlockWindow(float seconds, string reason)
        {
            if (!active)
            {
                return;
            }

            float until = Time.time + seconds;
            if (until > blockMainExpUntil)
            {
                blockMainExpUntil = until;
                blockReason = reason ?? string.Empty;
            }
        }

        private static bool IsProtectionWindowActive()
        {
            return offhandCreateDepth > 0 || Time.time <= blockMainExpUntil;
        }

        private static void CaptureMainBaselineIfIdle(string reason)
        {
            if (!active || Time.time <= mainHitGraceUntil)
            {
                return;
            }

            if (!hasMainBaseline || (!rollbackPending && Time.time > rollbackUntil))
            {
                RefreshMainBaseline(reason);
            }
        }

        private static void RefreshMainBaseline(string reason)
        {
            mainBaselineExp = GetMainExp();
            mainBaselineUseAddExp = GetMainUseAddExp(out mainBaselineUseAddExpExists);
            hasMainBaseline = true;
        }

        private static void RollbackMainStateIfChanged(string source)
        {
            if (!hasMainBaseline)
            {
                return;
            }

            int currentExp = GetMainExp();
            bool currentUseExists;
            float currentUseAddExp = GetMainUseAddExp(out currentUseExists);
            bool changed = currentExp != mainBaselineExp || !AreFloatEqual(currentUseAddExp, mainBaselineUseAddExp) || currentUseExists != mainBaselineUseAddExpExists;
            if (!changed)
            {
                return;
            }

            SetMainExp(mainBaselineExp);
            SetMainUseAddExp(mainBaselineUseAddExp, mainBaselineUseAddExpExists);
            rollbackMainExpCount++;
            if (rollbackMainExpCount <= RollbackLogLimit)
            {
                DualWieldLog.Info("DWT-024 rolled back main exp pollution. count=" + rollbackMainExpCount + ", source=" + source + ", exp=" + currentExp + "->" + mainBaselineExp + ", useAddExp=" + FormatUseAddExp(currentUseAddExp, currentUseExists) + "->" + FormatUseAddExp(mainBaselineUseAddExp, mainBaselineUseAddExpExists) + ", reason=" + rollbackReason, false);
            }
        }

        private static int GetMainExp()
        {
            try
            {
                return mainMartial != null ? mainMartial.exp : 0;
            }
            catch
            {
                return 0;
            }
        }

        private static void SetMainExp(int value)
        {
            try
            {
                if (mainMartial != null)
                {
                    mainMartial.exp = value;
                }
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("DWT-024 set main exp failed: " + ex.Message, false);
            }
        }

        private static float GetMainUseAddExp(out bool exists)
        {
            exists = false;
            try
            {
                if (player == null || player.martialUseAddExp == null || string.IsNullOrEmpty(mainSkillId))
                {
                    return 0f;
                }

                if (!player.martialUseAddExp.ContainsKey(mainSkillId))
                {
                    return 0f;
                }

                exists = true;
                return player.martialUseAddExp[mainSkillId];
            }
            catch
            {
                exists = false;
                return 0f;
            }
        }

        private static void SetMainUseAddExp(float value, bool exists)
        {
            try
            {
                if (player == null || player.martialUseAddExp == null || string.IsNullOrEmpty(mainSkillId))
                {
                    return;
                }

                if (exists)
                {
                    player.martialUseAddExp[mainSkillId] = value;
                    return;
                }

                if (player.martialUseAddExp.ContainsKey(mainSkillId))
                {
                    player.martialUseAddExp.Remove(mainSkillId);
                }
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("DWT-024 set main use-add-exp failed: " + ex.Message, false);
            }
        }

        private static bool IsSamePlayer(UnitCtrlPlayer owner)
        {
            if (owner == null)
            {
                return false;
            }

            if (player == null)
            {
                return true;
            }

            if (object.ReferenceEquals(owner, player))
            {
                return true;
            }

            try
            {
                return IL2CPP.Il2CppObjectBaseToPtr(owner) == IL2CPP.Il2CppObjectBaseToPtr(player);
            }
            catch
            {
                return true;
            }
        }

        private static bool IsMainTarget(string martialId, DataUnit.ActionMartialData martialData)
        {
            return MatchesSkill(martialId, martialData, mainSkillId, mainMartial);
        }

        private static bool IsOffhandTarget(string martialId, DataUnit.ActionMartialData martialData)
        {
            return MatchesSkill(martialId, martialData, offhandSkillId, offhandMartial);
        }

        private static bool MatchesSkill(string martialId, DataUnit.ActionMartialData martialData, string skillId, DataUnit.ActionMartialData expectedData)
        {
            if (string.IsNullOrEmpty(skillId))
            {
                return false;
            }

            if (!string.IsNullOrEmpty(martialId) && martialId == skillId)
            {
                return true;
            }

            string martialSoleId = GetMartialSoleId(martialData);
            if (!string.IsNullOrEmpty(martialSoleId) && martialSoleId == skillId)
            {
                return true;
            }

            string expectedSoleId = GetMartialSoleId(expectedData);
            return !string.IsNullOrEmpty(martialSoleId) && !string.IsNullOrEmpty(expectedSoleId) && martialSoleId == expectedSoleId;
        }

        private static string GetMartialSoleId(DataUnit.ActionMartialData martialData)
        {
            try
            {
                if (martialData != null && martialData.data != null)
                {
                    return martialData.data.soleID ?? string.Empty;
                }
            }
            catch
            {
            }

            return string.Empty;
        }

        private static string DescribeTarget(string martialId, DataUnit.ActionMartialData martialData)
        {
            if (!string.IsNullOrEmpty(martialId))
            {
                return martialId;
            }

            string soleId = GetMartialSoleId(martialData);
            return string.IsNullOrEmpty(soleId) ? "<unknown>" : soleId;
        }

        private static bool AreFloatEqual(float left, float right)
        {
            return Math.Abs(left - right) < 0.0001f;
        }

        private static string FormatUseAddExp(float value, bool exists)
        {
            return exists ? value.ToString("0.###") : "<missing>";
        }

        private static string FormatRemainingSeconds()
        {
            if (offhandCreateDepth > 0)
            {
                return "create-call";
            }

            float remaining = blockMainExpUntil - Time.time;
            if (remaining < 0f)
            {
                remaining = 0f;
            }

            return remaining.ToString("0.###") + "s";
        }
    }
}
