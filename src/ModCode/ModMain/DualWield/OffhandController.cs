using System;
using UnhollowerBaseLib;

namespace MOD_h6Zv8g.DualWield
{
    internal sealed class OffhandController
    {
        private const int FireIntervalFrames = 60;

        private Il2CppSystem.Action<ETypeData> onBattleStart;
        private Il2CppSystem.Action<ETypeData> onBattleEnd;
        private TimerCoroutine battleFrameTimer;
        private SkillAttack offhandSkill;
        private string offhandSkillId = string.Empty;
        private int offhandBaseId;
        private int frameCounter;
        private int fireCount;

        public void Init()
        {
            DualWieldLog.Info("OffhandController.Init registering battle events.", false);

            onBattleStart = (Il2CppSystem.Action<ETypeData>)OnBattleStart;
            onBattleEnd = (Il2CppSystem.Action<ETypeData>)OnBattleEnd;

            g.events.On(EBattleType.BattleStart, onBattleStart, 0, false);
            g.events.On(EBattleType.BattleEnd, onBattleEnd, 0, false);
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

            StopBattleState();
        }

        private void OnBattleStart(ETypeData e)
        {
            DualWieldLog.Info("BattleStart event received.", true);

            try
            {
                StopBattleState();
                TryStartOffhand();
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("Offhand battle start failed: " + ex, true);
                StopBattleState();
            }
        }

        private void OnBattleEnd(ETypeData e)
        {
            DualWieldLog.Info("BattleEnd event received.", true);
            StopBattleState();
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
                DualWieldLog.Info("Offhand skipped: no main normal attack skillLeft.", true);
                return;
            }

            var allMartial = g.world.playerUnit.data.unitData.allActionMartial;
            if (allMartial == null || !allMartial.ContainsKey(mainSkillId))
            {
                DualWieldLog.Info("Offhand skipped: main skill not found in allActionMartial: " + mainSkillId, true);
                return;
            }

            var martial = allMartial[mainSkillId];
            DataProps.PropsSkillData propsSkillData = martial.data.To<DataProps.PropsSkillData>();
            offhandBaseId = martial.data.propsInfoBase.baseID;
            offhandSkillId = mainSkillId;
            offhandSkill = BattleFactory.CreateSkill(2).Cast<SkillAttack>();
            offhandSkill.Init(player, propsSkillData);

            frameCounter = 0;
            fireCount = 0;
            battleFrameTimer = SceneType.battle.timer.Frame(new Action(OnBattleFrame), 1, true);
            DualWieldLog.Info("Offhand minimal controller started. skillId=" + offhandSkillId + ", baseId=" + offhandBaseId, true);
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

                frameCounter++;
                if (frameCounter < FireIntervalFrames)
                {
                    return;
                }

                frameCounter = 0;
                if (!offhandSkill.IsCreate(false, null, true, true))
                {
                    return;
                }

                offhandSkill.Create(player.posiBullet.position, player.posiBullet.up, null, null, null);
                fireCount++;
                if (fireCount <= 3)
                {
                    DualWieldLog.Info("Offhand fired. count=" + fireCount + ", skillId=" + offhandSkillId + ", baseId=" + offhandBaseId, true);
                }
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("Offhand frame failed: " + ex, true);
                StopBattleState();
            }
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

        private void StopBattleState()
        {
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
                DualWieldLog.Info("Offhand minimal controller stopped. skillId=" + offhandSkillId + ", fired=" + fireCount, true);
            }

            offhandSkill = null;
            offhandSkillId = string.Empty;
            offhandBaseId = 0;
            frameCounter = 0;
            fireCount = 0;
        }
    }
}
