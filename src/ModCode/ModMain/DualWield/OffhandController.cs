using System;
using EBattleTypeData;
using UnityEngine;
using UnhollowerBaseLib;

namespace MOD_h6Zv8g.DualWield
{
    internal sealed class OffhandController
    {
        private const int VisibleFireLogLimit = 3;
        private const float OffhandCreateDelaySeconds = 0.05f;
        private const int Dwt022FireLogLimit = 5;
        private const int Dwt022ExpChangeLogLimit = 12;
        private const int Dwt023HitLogLimit = 12;
        private const int MissingExp = -1;
        private const float MissingUseAddExp = -1f;

        private Il2CppSystem.Action<ETypeData> onBattleStart;
        private Il2CppSystem.Action<ETypeData> onBattleEnd;
        private Il2CppSystem.Action<ETypeData> onUnitHitDynIntHandler;
        private TimerCoroutine battleFrameTimer;
        private SkillAttack offhandSkill;
        private string offhandSkillId = string.Empty;
        private int offhandBaseId;
        private int fireCount;
        private bool hasPendingFire;
        private float pendingFireTime;
        private int queuedCount;
        private bool dwt022Active;
        private string dwt022MainSkillId = string.Empty;
        private int dwt022MainBaseId;
        private DataUnit.ActionMartialData dwt022MainMartial;
        private DataUnit.ActionMartialData dwt022OffhandMartial;
        private DataUnit.ActionMartialData dwt022RuntimeMartial;
        private int dwt022MainStartExp = MissingExp;
        private int dwt022OffhandStartExp = MissingExp;
        private int dwt022RuntimeStartExp = MissingExp;
        private int dwt022LastMainExp = MissingExp;
        private int dwt022LastOffhandExp = MissingExp;
        private int dwt022LastRuntimeExp = MissingExp;
        private float dwt022MainStartUseAddExp = MissingUseAddExp;
        private float dwt022OffhandStartUseAddExp = MissingUseAddExp;
        private float dwt022LastMainUseAddExp = MissingUseAddExp;
        private float dwt022LastOffhandUseAddExp = MissingUseAddExp;
        private int dwt022ExpChangeLogCount;
        private int dwt023HitLogCount;
        private string dwt023LastOffhandSkillCreateSoleId = string.Empty;
        private int dwt023LastOffhandCreateMainSkillId;
        private float dwt023LastOffhandCreateTime;
        private bool dwt023LastOffhandCreateDataExplicit;

        public void Init()
        {
            DualWieldLog.Info("OffhandController.Init registering battle events.", false);

            onBattleStart = (Il2CppSystem.Action<ETypeData>)OnBattleStart;
            onBattleEnd = (Il2CppSystem.Action<ETypeData>)OnBattleEnd;
            onUnitHitDynIntHandler = (Il2CppSystem.Action<ETypeData>)OnUnitHitDynIntHandler;

            g.events.On(EBattleType.BattleStart, onBattleStart, 0, false);
            g.events.On(EBattleType.BattleEnd, onBattleEnd, 0, false);
            g.events.On(EBattleType.UnitHitDynIntHandler, onUnitHitDynIntHandler, 0, false);
        }

        public void Destroy()
        {
            DualWieldLog.Info("OffhandController.Destroy unregistering battle events.", false);

            if (onBattleStart != null)
            {
                g.events.Off(EBattleType.BattleStart, onBattleStart);
                onBattleStart = null;
            }

            if (onBattleEnd != null)
            {
                g.events.Off(EBattleType.BattleEnd, onBattleEnd);
                onBattleEnd = null;
            }

            if (onUnitHitDynIntHandler != null)
            {
                g.events.Off(EBattleType.UnitHitDynIntHandler, onUnitHitDynIntHandler);
                onUnitHitDynIntHandler = null;
            }

            StopBattleState("destroy");
        }

        private void OnBattleStart(ETypeData e)
        {
            DualWieldLog.Info("BattleStart event received.", false);

            try
            {
                StopBattleState("battle-start-reset");
                TryStartOffhand();
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("Offhand battle start failed: " + ex, true);
                StopBattleState("battle-start-failed");
            }
        }

        private void OnBattleEnd(ETypeData e)
        {
            DualWieldLog.Info("BattleEnd event received.", false);
            StopBattleState("battle-end");
        }

        private void TryStartOffhand()
        {
            UnitCtrlPlayer player = GetPlayer();
            if (player == null)
            {
                DualWieldLog.Info("Offhand skipped: player not ready.", true);
                return;
            }

            string mainSkillId = g.world.playerUnit.data.unitData.skillLeft;
            if (string.IsNullOrEmpty(mainSkillId))
            {
                DualWieldLoadoutGuard.PromoteSavedOffhandToMain("battle-start-fallback", true);
                return;
            }

            var allMartial = g.world.playerUnit.data.unitData.allActionMartial;
            if (allMartial == null || !allMartial.ContainsKey(mainSkillId))
            {
                DualWieldLog.Info("Offhand skipped: main skill not found in allActionMartial: " + mainSkillId, true);
                return;
            }

            var mainMartial = allMartial[mainSkillId];

            DualWieldSaveStore.EnsureLoaded();
            string selectedOffhandSkillId = DualWieldSaveStore.OffhandSkillId;
            if (string.IsNullOrEmpty(selectedOffhandSkillId))
            {
                DualWieldLog.Info("Offhand skipped: no saved offhand selected.", false);
                return;
            }

            if (!allMartial.ContainsKey(selectedOffhandSkillId))
            {
                DualWieldLog.Info("Offhand skipped: saved offhand skill not found in allActionMartial: " + selectedOffhandSkillId, true);
                DualWieldSaveStore.ClearOffhandSkillId("saved-skill-missing");
                return;
            }

            if (selectedOffhandSkillId == mainSkillId)
            {
                DualWieldLog.Info("Offhand skipped: saved offhand is already main normal attack. skillId=" + selectedOffhandSkillId, true);
                DualWieldSaveStore.ClearOffhandSkillId("saved-offhand-already-main");
                return;
            }

            var martial = allMartial[selectedOffhandSkillId];
            DataProps.PropsSkillData propsSkillData = martial.data.To<DataProps.PropsSkillData>();
            offhandBaseId = martial.data.propsInfoBase.baseID;
            offhandSkillId = selectedOffhandSkillId;
            offhandSkill = BattleFactory.CreateSkill(2).Cast<SkillAttack>();
            offhandSkill.Init(player, propsSkillData);
            StartDwt022Diagnostics(mainSkillId, mainMartial, selectedOffhandSkillId, martial);
            DualWieldAttributionGuard.Configure(player, mainSkillId, mainMartial, selectedOffhandSkillId, martial);

            fireCount = 0;
            queuedCount = 0;
            hasPendingFire = false;
            pendingFireTime = 0f;
            battleFrameTimer = SceneType.battle.timer.Frame(new Action(OnBattleFrame), 1, true);
            DualWieldLog.Info("Offhand controlled trigger started. skillId=" + offhandSkillId + ", baseId=" + offhandBaseId + ", source=saved", true);
        }

        private void OnBattleFrame()
        {
            try
            {
                UnitCtrlPlayer player = GetPlayer();
                if (player == null || offhandSkill == null)
                {
                    return;
                }

                DualWieldAttributionGuard.Tick("frame-before-log");
                TryLogDwt022ExpChange("frame");

                if (hasPendingFire)
                {
                    TryFirePending(player);
                    DualWieldAttributionGuard.Tick("frame-after-pending");
                    TryLogDwt022ExpChange("frame-after-pending");
                    return;
                }

                if (!Input.GetKey(g.data.globle.key.battleSkill1))
                {
                    return;
                }

                if (!offhandSkill.IsCreate(false, null, true, true))
                {
                    return;
                }

                QueueOffhandFire();
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("Offhand frame failed: " + ex, true);
                StopBattleState("frame-failed");
            }
        }

        private void QueueOffhandFire()
        {
            hasPendingFire = true;
            pendingFireTime = Time.time + OffhandCreateDelaySeconds;
            queuedCount++;
            DualWieldAttributionGuard.MarkOffhandQueued(queuedCount);
            if (queuedCount <= VisibleFireLogLimit)
            {
                DualWieldLog.Info("Offhand queued from normal attack input. count=" + queuedCount + ", delay=" + OffhandCreateDelaySeconds + "s, skillId=" + offhandSkillId + ", baseId=" + offhandBaseId, true);
            }
        }

        private void TryFirePending(UnitCtrlPlayer player)
        {
            if (Time.time < pendingFireTime)
            {
                return;
            }

            hasPendingFire = false;
            pendingFireTime = 0f;

            if (offhandSkill == null || player == null || player.isDestroy || player.isDie)
            {
                return;
            }

            if (!offhandSkill.IsCreate(false, null, true, true))
            {
                return;
            }

            int mainBeforeExp = GetMartialExp(dwt022MainMartial);
            int offhandBeforeExp = GetMartialExp(dwt022OffhandMartial);
            int runtimeBeforeExp = GetMartialExp(GetDwt022RuntimeMartial());
            SkillCreateData offhandCreateData = CreateExplicitOffhandSkillCreateData();
            int nextFireIndex = fireCount + 1;
            try
            {
                DualWieldAttributionGuard.BeginOffhandCreate(nextFireIndex);
                offhandSkill.Create(player.posiBullet.position, player.posiBullet.up, null, null, offhandCreateData);
            }
            finally
            {
                DualWieldAttributionGuard.EndOffhandCreate();
            }

            fireCount = nextFireIndex;
            DualWieldAttributionGuard.MarkOffhandFired(fireCount);
            if (fireCount <= VisibleFireLogLimit)
            {
                DualWieldLog.Info("Offhand fired after delay. count=" + fireCount + ", delay=" + OffhandCreateDelaySeconds + "s, skillId=" + offhandSkillId + ", baseId=" + offhandBaseId, true);
            }

            LogDwt023CreateSnapshot(offhandCreateData);

            LogDwt022FireSnapshot(mainBeforeExp, offhandBeforeExp, runtimeBeforeExp);
        }

        private UnitCtrlPlayer GetPlayer()
        {
            if (SceneType.battle == null || SceneType.battle.battleMap == null)
            {
                return null;
            }

            UnitCtrlPlayer player = SceneType.battle.battleMap.playerUnitCtrl;
            if (player == null || player.isDestroy || player.isDie)
            {
                return null;
            }

            return player;
        }

        private void StartDwt022Diagnostics(string mainSkillId, DataUnit.ActionMartialData mainMartial, string selectedOffhandSkillId, DataUnit.ActionMartialData offhandMartial)
        {
            dwt022Active = true;
            dwt022MainSkillId = mainSkillId ?? string.Empty;
            dwt022MainMartial = mainMartial;
            dwt022OffhandMartial = offhandMartial;
            dwt022RuntimeMartial = GetDwt022RuntimeMartial();
            dwt022MainBaseId = GetMartialBaseId(dwt022MainMartial);
            dwt022MainStartExp = GetMartialExp(dwt022MainMartial);
            dwt022OffhandStartExp = GetMartialExp(dwt022OffhandMartial);
            dwt022RuntimeStartExp = GetMartialExp(dwt022RuntimeMartial);
            dwt022LastMainExp = dwt022MainStartExp;
            dwt022LastOffhandExp = dwt022OffhandStartExp;
            dwt022LastRuntimeExp = dwt022RuntimeStartExp;
            UnitCtrlPlayer player = GetPlayer();
            dwt022MainStartUseAddExp = GetMartialUseAddExp(player, dwt022MainSkillId);
            dwt022OffhandStartUseAddExp = GetMartialUseAddExp(player, offhandSkillId);
            dwt022LastMainUseAddExp = dwt022MainStartUseAddExp;
            dwt022LastOffhandUseAddExp = dwt022OffhandStartUseAddExp;
            dwt022ExpChangeLogCount = 0;

            DualWieldLog.Info("DWT-022 start. mainSkillId=" + dwt022MainSkillId + ", mainBaseId=" + dwt022MainBaseId + ", mainExp=" + FormatExp(dwt022MainStartExp) + ", mainUseAddExp=" + FormatUseAddExp(dwt022MainStartUseAddExp) + ", offhandSkillId=" + offhandSkillId + ", offhandBaseId=" + offhandBaseId + ", offhandExp=" + FormatExp(dwt022OffhandStartExp) + ", offhandUseAddExp=" + FormatUseAddExp(dwt022OffhandStartUseAddExp), true);
            DualWieldLog.Info("DWT-022 runtime binding. runtimeSoleId=" + GetMartialSoleId(dwt022RuntimeMartial) + ", runtimeBaseId=" + GetMartialBaseId(dwt022RuntimeMartial) + ", runtimeExp=" + FormatExp(dwt022RuntimeStartExp) + ", binding=" + DescribeRuntimeBinding(dwt022RuntimeMartial), true);
        }

        private void TryLogDwt022ExpChange(string source)
        {
            if (!dwt022Active || dwt022ExpChangeLogCount >= Dwt022ExpChangeLogLimit)
            {
                return;
            }

            DataUnit.ActionMartialData runtimeMartial = GetDwt022RuntimeMartial();
            int mainExp = GetMartialExp(dwt022MainMartial);
            int offhandExp = GetMartialExp(dwt022OffhandMartial);
            int runtimeExp = GetMartialExp(runtimeMartial);
            UnitCtrlPlayer player = GetPlayer();
            float mainUseAddExp = GetMartialUseAddExp(player, dwt022MainSkillId);
            float offhandUseAddExp = GetMartialUseAddExp(player, offhandSkillId);

            if (mainExp == dwt022LastMainExp && offhandExp == dwt022LastOffhandExp && runtimeExp == dwt022LastRuntimeExp && AreUseAddExpEqual(mainUseAddExp, dwt022LastMainUseAddExp) && AreUseAddExpEqual(offhandUseAddExp, dwt022LastOffhandUseAddExp))
            {
                return;
            }

            dwt022ExpChangeLogCount++;
            DualWieldLog.Info("DWT-022 exp change. source=" + source + ", fired=" + fireCount + ", main=" + FormatExpTransition(dwt022LastMainExp, mainExp, dwt022MainStartExp) + ", offhand=" + FormatExpTransition(dwt022LastOffhandExp, offhandExp, dwt022OffhandStartExp) + ", runtime=" + FormatExpTransition(dwt022LastRuntimeExp, runtimeExp, dwt022RuntimeStartExp) + ", mainUseAddExp=" + FormatUseAddExpTransition(dwt022LastMainUseAddExp, mainUseAddExp, dwt022MainStartUseAddExp) + ", offhandUseAddExp=" + FormatUseAddExpTransition(dwt022LastOffhandUseAddExp, offhandUseAddExp, dwt022OffhandStartUseAddExp) + ", runtimeBinding=" + DescribeRuntimeBinding(runtimeMartial), false);

            dwt022LastMainExp = mainExp;
            dwt022LastOffhandExp = offhandExp;
            dwt022LastRuntimeExp = runtimeExp;
            dwt022LastMainUseAddExp = mainUseAddExp;
            dwt022LastOffhandUseAddExp = offhandUseAddExp;
            dwt022RuntimeMartial = runtimeMartial;
        }

        private void LogDwt022FireSnapshot(int mainBeforeExp, int offhandBeforeExp, int runtimeBeforeExp)
        {
            if (!dwt022Active || fireCount > Dwt022FireLogLimit)
            {
                return;
            }

            DataUnit.ActionMartialData runtimeMartial = GetDwt022RuntimeMartial();
            int mainAfterExp = GetMartialExp(dwt022MainMartial);
            int offhandAfterExp = GetMartialExp(dwt022OffhandMartial);
            int runtimeAfterExp = GetMartialExp(runtimeMartial);
            UnitCtrlPlayer player = GetPlayer();
            float mainUseAddExp = GetMartialUseAddExp(player, dwt022MainSkillId);
            float offhandUseAddExp = GetMartialUseAddExp(player, offhandSkillId);

            DualWieldLog.Info("DWT-022 fire snapshot. count=" + fireCount + ", main=" + FormatExpTransition(mainBeforeExp, mainAfterExp, dwt022MainStartExp) + ", offhand=" + FormatExpTransition(offhandBeforeExp, offhandAfterExp, dwt022OffhandStartExp) + ", runtime=" + FormatExpTransition(runtimeBeforeExp, runtimeAfterExp, dwt022RuntimeStartExp) + ", mainUseAddExp=" + FormatUseAddExp(mainUseAddExp) + ", offhandUseAddExp=" + FormatUseAddExp(offhandUseAddExp) + ", runtimeBinding=" + DescribeRuntimeBinding(runtimeMartial), false);
            dwt022LastMainExp = mainAfterExp;
            dwt022LastOffhandExp = offhandAfterExp;
            dwt022LastRuntimeExp = runtimeAfterExp;
            dwt022LastMainUseAddExp = mainUseAddExp;
            dwt022LastOffhandUseAddExp = offhandUseAddExp;
            dwt022RuntimeMartial = runtimeMartial;
        }

        private SkillCreateData CreateExplicitOffhandSkillCreateData()
        {
            try
            {
                if (offhandSkill == null)
                {
                    return null;
                }

                SkillCreateData data = offhandSkill.UseSkillCreateData();
                if (data != null)
                {
                    data.createSkillBase = offhandSkill;
                    dwt023LastOffhandSkillCreateSoleId = data.skillCreateSoleID ?? string.Empty;
                    dwt023LastOffhandCreateMainSkillId = data.mainSkillID;
                    dwt023LastOffhandCreateDataExplicit = true;
                    dwt023LastOffhandCreateTime = Time.time;
                }

                return data;
            }
            catch (Exception ex)
            {
                dwt023LastOffhandSkillCreateSoleId = string.Empty;
                dwt023LastOffhandCreateMainSkillId = 0;
                dwt023LastOffhandCreateDataExplicit = false;
                dwt023LastOffhandCreateTime = Time.time;
                DualWieldLog.Info("DWT-023 explicit SkillCreateData failed: " + ex.Message, false);
                return null;
            }
        }

        private void LogDwt023CreateSnapshot(SkillCreateData createData)
        {
            if (fireCount > Dwt022FireLogLimit)
            {
                return;
            }

            SkillDataAttack attackData = GetOffhandAttackData();
            DualWieldLog.Info("DWT-023 create snapshot. count=" + fireCount + ", explicitCreateData=" + (createData != null) + ", createSoleId=" + GetSkillCreateSoleId(createData) + ", createMainSkillId=" + GetSkillCreateMainSkillId(createData) + ", createSkillBase=" + DescribeSkillBase(createData != null ? createData.createSkillBase : null) + ", offhandSkillDataId=" + GetSkillAttackDataSkillId(attackData) + ", offhandMainSkillId=" + GetSkillBaseMainSkillId(offhandSkill) + ", phy=" + FormatDynIntValue(GetSkillBasePhysicalDmg(offhandSkill)) + ", magic=" + FormatDynIntValue(GetSkillBaseMagicDmg(offhandSkill)) + ", weaponType=" + FormatDynIntValue(GetSkillBaseWeaponType(offhandSkill)) + ", magicType=" + FormatDynIntValue(GetSkillBaseMagicType(offhandSkill)), false);
        }

        private void OnUnitHitDynIntHandler(ETypeData e)
        {
            try
            {
                if (offhandSkill == null)
                {
                    return;
                }

                UnitHitDynIntHandler data = e.Cast<UnitHitDynIntHandler>();
                if (data == null || data.hitData == null)
                {
                    return;
                }

                MartialTool.HitData hitData = data.hitData;
                SkillBase hitSkillBase = hitData.skillBase;
                SkillCreateData createData = hitData.skillCreateData;
                SkillAttack mainRuntimeSkill = GetMainRuntimeSkill();
                bool matchesOffhandSkill = IsSameSkillBase(hitSkillBase, offhandSkill) || IsSameSkillBase(createData != null ? createData.createSkillBase : null, offhandSkill);
                bool nearOffhandCreate = dwt023LastOffhandCreateTime > 0f && Time.time - dwt023LastOffhandCreateTime <= 2.0f;
                bool createSoleMatches = !string.IsNullOrEmpty(dwt023LastOffhandSkillCreateSoleId) && createData != null && createData.skillCreateSoleID == dwt023LastOffhandSkillCreateSoleId;
                bool suspiciousMainSkill = IsSameSkillBase(hitSkillBase, mainRuntimeSkill) || IsSameSkillBase(createData != null ? createData.createSkillBase : null, mainRuntimeSkill);

                if (!matchesOffhandSkill && !createSoleMatches && !(nearOffhandCreate && suspiciousMainSkill))
                {
                    return;
                }

                if (suspiciousMainSkill && !matchesOffhandSkill && !createSoleMatches)
                {
                    DualWieldAttributionGuard.MarkMainHit("skill-base");
                }
                else
                {
                    string hitGuardReason = matchesOffhandSkill ? "skill-base" : (createSoleMatches ? "create-sole" : "near-create-main-suspicious");
                    DualWieldAttributionGuard.MarkPotentialOffhandHit(hitGuardReason);
                }

                if (dwt023HitLogCount >= Dwt023HitLogLimit)
                {
                    return;
                }

                dwt023HitLogCount++;
                DualWieldLog.Info("DWT-023 hit attribution. index=" + dwt023HitLogCount + ", fired=" + fireCount + ", matchesOffhandSkill=" + matchesOffhandSkill + ", createSoleMatches=" + createSoleMatches + ", nearOffhandCreate=" + nearOffhandCreate + ", suspiciousMainSkill=" + suspiciousMainSkill + ", hitSkill=" + DescribeSkillBase(hitSkillBase) + ", createSkill=" + DescribeSkillBase(createData != null ? createData.createSkillBase : null) + ", createSoleId=" + GetSkillCreateSoleId(createData) + ", createMainSkillId=" + GetSkillCreateMainSkillId(createData) + ", hitValue=" + hitData.hitValue + ", dynBase=" + FormatDynIntBaseValue(data.dynV) + ", dynValue=" + FormatDynIntValue(data.dynV) + ", weaponType=" + hitData.weaponType + ", magicType=" + hitData.magicType + ", basCoefficient=" + hitData.basCoefficient + ", explicitOffhandCreateData=" + dwt023LastOffhandCreateDataExplicit, false);
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("DWT-023 hit attribution failed: " + ex.Message, false);
            }
        }

        private void LogDwt022Summary(string reason)
        {
            if (!dwt022Active)
            {
                return;
            }

            DataUnit.ActionMartialData runtimeMartial = GetDwt022RuntimeMartial();
            int mainEndExp = GetMartialExp(dwt022MainMartial);
            int offhandEndExp = GetMartialExp(dwt022OffhandMartial);
            int runtimeEndExp = GetMartialExp(runtimeMartial);
            UnitCtrlPlayer player = GetPlayer();
            float mainUseAddExp = GetMartialUseAddExp(player, dwt022MainSkillId);
            float offhandUseAddExp = GetMartialUseAddExp(player, offhandSkillId);
            DualWieldLog.Info("DWT-022 summary. reason=" + reason + ", fired=" + fireCount + ", mainSkillId=" + dwt022MainSkillId + ", mainExp=" + FormatExpTransition(dwt022MainStartExp, mainEndExp, dwt022MainStartExp) + ", mainUseAddExp=" + FormatUseAddExpTransition(dwt022MainStartUseAddExp, mainUseAddExp, dwt022MainStartUseAddExp) + ", offhandSkillId=" + offhandSkillId + ", offhandExp=" + FormatExpTransition(dwt022OffhandStartExp, offhandEndExp, dwt022OffhandStartExp) + ", offhandUseAddExp=" + FormatUseAddExpTransition(dwt022OffhandStartUseAddExp, offhandUseAddExp, dwt022OffhandStartUseAddExp) + ", runtimeSoleId=" + GetMartialSoleId(runtimeMartial) + ", runtimeBaseId=" + GetMartialBaseId(runtimeMartial) + ", runtimeExp=" + FormatExpTransition(dwt022RuntimeStartExp, runtimeEndExp, dwt022RuntimeStartExp) + ", runtimeBinding=" + DescribeRuntimeBinding(runtimeMartial), false);
        }

        private DataUnit.ActionMartialData GetDwt022RuntimeMartial()
        {
            try
            {
                if (offhandSkill != null && offhandSkill.data != null && offhandSkill.data.actionMartialData != null)
                {
                    return offhandSkill.data.actionMartialData;
                }
            }
            catch
            {
            }

            return dwt022RuntimeMartial;
        }

        private static int GetMartialExp(DataUnit.ActionMartialData martial)
        {
            try
            {
                return martial != null ? martial.exp : MissingExp;
            }
            catch
            {
                return MissingExp;
            }
        }

        private static int GetMartialBaseId(DataUnit.ActionMartialData martial)
        {
            try
            {
                if (martial != null && martial.data != null && martial.data.propsInfoBase != null)
                {
                    return martial.data.propsInfoBase.baseID;
                }
            }
            catch
            {
            }

            return 0;
        }

        private static string GetMartialSoleId(DataUnit.ActionMartialData martial)
        {
            try
            {
                if (martial != null && martial.data != null)
                {
                    return martial.data.soleID ?? string.Empty;
                }
            }
            catch
            {
            }

            return string.Empty;
        }

        private static float GetMartialUseAddExp(UnitCtrlPlayer player, string skillId)
        {
            try
            {
                if (player == null || player.martialUseAddExp == null || string.IsNullOrEmpty(skillId))
                {
                    return MissingUseAddExp;
                }

                if (!player.martialUseAddExp.ContainsKey(skillId))
                {
                    return 0f;
                }

                return player.martialUseAddExp[skillId];
            }
            catch
            {
                return MissingUseAddExp;
            }
        }

        private SkillDataAttack GetOffhandAttackData()
        {
            try
            {
                return offhandSkill != null && offhandSkill.data != null ? offhandSkill.data : null;
            }
            catch
            {
                return null;
            }
        }

        private SkillAttack GetMainRuntimeSkill()
        {
            try
            {
                UnitCtrlPlayer player = GetPlayer();
                if (player == null || player.skills == null)
                {
                    return null;
                }

                for (int i = 0; i < player.skills.Count; i++)
                {
                    SkillAttack skill = player.skills[i];
                    if (skill == null || skill == offhandSkill || skill.data == null || skill.data.actionMartialData == null)
                    {
                        continue;
                    }

                    if (DescribeRuntimeBinding(skill.data.actionMartialData) == "main")
                    {
                        return skill;
                    }
                }
            }
            catch
            {
            }

            return null;
        }

        private static bool IsSameSkillBase(SkillBase left, SkillBase right)
        {
            if (left == null || right == null)
            {
                return false;
            }

            if (object.ReferenceEquals(left, right))
            {
                return true;
            }

            try
            {
                return left.Pointer == right.Pointer;
            }
            catch
            {
                return false;
            }
        }

        private static string DescribeSkillBase(SkillBase skill)
        {
            if (skill == null)
            {
                return "<null>";
            }

            return "mainSkillID=" + GetSkillBaseMainSkillId(skill) + ",phy=" + FormatDynIntValue(GetSkillBasePhysicalDmg(skill)) + ",magic=" + FormatDynIntValue(GetSkillBaseMagicDmg(skill)) + ",weaponType=" + FormatDynIntValue(GetSkillBaseWeaponType(skill)) + ",magicType=" + FormatDynIntValue(GetSkillBaseMagicType(skill));
        }

        private static int GetSkillBaseMainSkillId(SkillBase skill)
        {
            try
            {
                return skill != null && skill.data != null ? skill.data.mainSkillID : 0;
            }
            catch
            {
                return 0;
            }
        }

        private static int GetSkillAttackDataSkillId(SkillDataAttack data)
        {
            try
            {
                return data != null ? data.skillID : 0;
            }
            catch
            {
                return 0;
            }
        }

        private static string GetSkillCreateSoleId(SkillCreateData data)
        {
            try
            {
                return data != null ? data.skillCreateSoleID ?? string.Empty : string.Empty;
            }
            catch
            {
                return string.Empty;
            }
        }

        private static int GetSkillCreateMainSkillId(SkillCreateData data)
        {
            try
            {
                return data != null ? data.mainSkillID : 0;
            }
            catch
            {
                return 0;
            }
        }

        private static DynInt GetSkillBasePhysicalDmg(SkillBase skill)
        {
            return skill != null && skill.data != null ? skill.data.phycicalDmg : null;
        }

        private static DynInt GetSkillBaseMagicDmg(SkillBase skill)
        {
            return skill != null && skill.data != null ? skill.data.magicDmg : null;
        }

        private static DynInt GetSkillBaseWeaponType(SkillBase skill)
        {
            return skill != null && skill.data != null ? skill.data.weaponType : null;
        }

        private static DynInt GetSkillBaseMagicType(SkillBase skill)
        {
            return skill != null && skill.data != null ? skill.data.magicType : null;
        }

        private static string FormatDynIntValue(DynInt value)
        {
            try
            {
                return value != null ? value.value.ToString() : "<missing>";
            }
            catch
            {
                return "<error>";
            }
        }

        private static string FormatDynIntBaseValue(DynInt value)
        {
            try
            {
                return value != null ? value.baseValue.ToString() : "<missing>";
            }
            catch
            {
                return "<error>";
            }
        }

        private string DescribeRuntimeBinding(DataUnit.ActionMartialData runtimeMartial)
        {
            bool matchesMain = IsSameMartial(runtimeMartial, dwt022MainMartial, dwt022MainSkillId);
            bool matchesOffhand = IsSameMartial(runtimeMartial, dwt022OffhandMartial, offhandSkillId);
            if (matchesMain && matchesOffhand)
            {
                return "main-and-offhand";
            }

            if (matchesOffhand)
            {
                return "offhand";
            }

            if (matchesMain)
            {
                return "main";
            }

            return runtimeMartial == null ? "null" : "detached-or-unknown";
        }

        private static bool IsSameMartial(DataUnit.ActionMartialData left, DataUnit.ActionMartialData right, string rightSkillId)
        {
            if (left == null || right == null)
            {
                return false;
            }

            if (object.ReferenceEquals(left, right))
            {
                return true;
            }

            string leftSoleId = GetMartialSoleId(left);
            string rightSoleId = GetMartialSoleId(right);
            if (!string.IsNullOrEmpty(leftSoleId) && !string.IsNullOrEmpty(rightSoleId) && leftSoleId == rightSoleId)
            {
                return true;
            }

            return !string.IsNullOrEmpty(leftSoleId) && !string.IsNullOrEmpty(rightSkillId) && leftSoleId == rightSkillId;
        }

        private static bool AreUseAddExpEqual(float left, float right)
        {
            return Math.Abs(left - right) < 0.0001f;
        }

        private static string FormatExp(int exp)
        {
            return exp == MissingExp ? "<missing>" : exp.ToString();
        }

        private static string FormatExpTransition(int before, int after, int start)
        {
            if (before == MissingExp && after == MissingExp)
            {
                return "<missing>";
            }

            return FormatExp(before) + "->" + FormatExp(after) + "(lastDelta=" + FormatExpDelta(before, after) + ",totalDelta=" + FormatExpDelta(start, after) + ")";
        }

        private static string FormatExpDelta(int before, int after)
        {
            if (before == MissingExp || after == MissingExp)
            {
                return "?";
            }

            return (after - before).ToString();
        }

        private static string FormatUseAddExp(float value)
        {
            return value < 0f ? "<missing>" : value.ToString("0.###");
        }

        private static string FormatUseAddExpTransition(float before, float after, float start)
        {
            if (before < 0f && after < 0f)
            {
                return "<missing>";
            }

            return FormatUseAddExp(before) + "->" + FormatUseAddExp(after) + "(lastDelta=" + FormatUseAddExpDelta(before, after) + ",totalDelta=" + FormatUseAddExpDelta(start, after) + ")";
        }

        private static string FormatUseAddExpDelta(float before, float after)
        {
            if (before < 0f || after < 0f)
            {
                return "?";
            }

            return (after - before).ToString("0.###");
        }

        private void ResetDwt022Diagnostics()
        {
            dwt022Active = false;
            dwt022MainSkillId = string.Empty;
            dwt022MainBaseId = 0;
            dwt022MainMartial = null;
            dwt022OffhandMartial = null;
            dwt022RuntimeMartial = null;
            dwt022MainStartExp = MissingExp;
            dwt022OffhandStartExp = MissingExp;
            dwt022RuntimeStartExp = MissingExp;
            dwt022LastMainExp = MissingExp;
            dwt022LastOffhandExp = MissingExp;
            dwt022LastRuntimeExp = MissingExp;
            dwt022MainStartUseAddExp = MissingUseAddExp;
            dwt022OffhandStartUseAddExp = MissingUseAddExp;
            dwt022LastMainUseAddExp = MissingUseAddExp;
            dwt022LastOffhandUseAddExp = MissingUseAddExp;
            dwt022ExpChangeLogCount = 0;
            dwt023HitLogCount = 0;
            dwt023LastOffhandSkillCreateSoleId = string.Empty;
            dwt023LastOffhandCreateMainSkillId = 0;
            dwt023LastOffhandCreateTime = 0f;
            dwt023LastOffhandCreateDataExplicit = false;
        }

        private void StopBattleState(string reason)
        {
            LogDwt022Summary(reason);
            DualWieldAttributionGuard.Clear(reason);

            if (battleFrameTimer != null)
            {
                if (SceneType.battle != null)
                {
                    SceneType.battle.timer.Stop(battleFrameTimer);
                }
                battleFrameTimer = null;
            }

            if (offhandSkill != null)
            {
                DualWieldLog.Info("Offhand controlled trigger stopped. skillId=" + offhandSkillId + ", fired=" + fireCount, false);
            }

            offhandSkill = null;
            offhandSkillId = string.Empty;
            offhandBaseId = 0;
            fireCount = 0;
            queuedCount = 0;
            hasPendingFire = false;
            pendingFireTime = 0f;
            ResetDwt022Diagnostics();
        }
    }
}
