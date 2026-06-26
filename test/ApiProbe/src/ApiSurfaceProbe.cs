using System;
using System.Reflection;
using EBattleTypeData;
using EGameTypeData;
using HarmonyLib;
using UnhollowerBaseLib;
using UnityEngine;
using UnityEngine.UI;

namespace DualWieldMod.ApiProbe
{
    /// <summary>
    /// Compile-only API probe. Do not package or execute this as a gameplay MOD.
    /// </summary>
    public sealed class ApiSurfaceProbe
    {
        private const string SaveGroup = "DualWieldMod.ApiProbe";
        private static TimerCoroutine updateCoroutine;
        private static Harmony harmony;
        private static SkillAttack offhandSkill;
        private static Il2CppSystem.Action<ETypeData> onBattleStart;
        private static Il2CppSystem.Action<ETypeData> onBattleEnd;
        private static Il2CppSystem.Action<ETypeData> onOpenUIEnd;
        private static Il2CppSystem.Action<ETypeData> onSaveData;
        private static Il2CppSystem.Action<ETypeData> onUnitHit;

        public void Init()
        {
            if (harmony != null)
            {
                harmony.UnpatchSelf();
                harmony = null;
            }

            harmony = new Harmony("DualWieldMod.ApiProbe");
            harmony.PatchAll(Assembly.GetExecutingAssembly());

            onBattleStart = (Il2CppSystem.Action<ETypeData>)OnBattleStart;
            onBattleEnd = (Il2CppSystem.Action<ETypeData>)OnBattleEnd;
            onOpenUIEnd = (Il2CppSystem.Action<ETypeData>)OnOpenUIEnd;
            onSaveData = (Il2CppSystem.Action<ETypeData>)OnSaveData;
            onUnitHit = (Il2CppSystem.Action<ETypeData>)OnUnitHitDynIntHandler;

            g.events.On(EBattleType.BattleStart, onBattleStart, 0, false);
            g.events.On(EBattleType.BattleEnd, onBattleEnd, 0, false);
            g.events.On(EGameType.OpenUIEnd, onOpenUIEnd, 0, false);
            g.events.On(EGameType.SaveData, onSaveData, 0, false);
            g.events.On(EBattleType.UnitHitDynIntHandler, onUnitHit, 0, false);

            updateCoroutine = g.timer.Frame(new Action(OnFrame), 1, true);
        }

        public void Destroy()
        {
            g.events.Off(EBattleType.BattleStart, onBattleStart);
            g.events.Off(EBattleType.BattleEnd, onBattleEnd);
            g.events.Off(EGameType.OpenUIEnd, onOpenUIEnd);
            g.events.Off(EGameType.SaveData, onSaveData);
            g.events.Off(EBattleType.UnitHitDynIntHandler, onUnitHit);

            if (updateCoroutine != null)
            {
                g.timer.Stop(updateCoroutine);
                updateCoroutine = null;
            }

            if (harmony != null)
            {
                harmony.UnpatchSelf();
                harmony = null;
            }
        }

        private static void OnSaveData(ETypeData e)
        {
            g.data.obj.SetString(SaveGroup, "probe", "ok");
            if (g.data.obj.ContainsKey(SaveGroup, "probe"))
            {
                string value = g.data.obj.GetString(SaveGroup, "probe");
                if (value == "delete")
                {
                    g.data.obj.DelGroup(SaveGroup);
                }
            }
        }

        private static void OnBattleStart(ETypeData e)
        {
            if (SceneType.battle == null || SceneType.battle.battleMap == null)
            {
                return;
            }

            UnitCtrlPlayer player = SceneType.battle.battleMap.playerUnitCtrl;
            if (player == null || player.isDestroy || player.isDie)
            {
                return;
            }

            string mainSkillId = g.world.playerUnit.data.unitData.skillLeft;
            if (string.IsNullOrEmpty(mainSkillId))
            {
                return;
            }

            if (!g.world.playerUnit.data.unitData.allActionMartial.ContainsKey(mainSkillId))
            {
                return;
            }

            var martial = g.world.playerUnit.data.unitData.allActionMartial[mainSkillId];
            int baseId = martial.data.propsInfoBase.baseID;
            ConfBattleSkillAttackItem attackConfig = g.conf.battleSkillAttack.GetItem(baseId);
            DataProps.PropsSkillData propsSkillData = martial.data.To<DataProps.PropsSkillData>();

            offhandSkill = BattleFactory.CreateSkill(2).Cast<SkillAttack>();
            offhandSkill.Init(player, propsSkillData);

            if (attackConfig.icon == "__never__")
            {
                UITipItem.AddTip(attackConfig.icon);
            }
        }

        private static void OnBattleEnd(ETypeData e)
        {
            offhandSkill = null;
        }

        private static void OnFrame()
        {
            if (SceneType.battle == null || SceneType.battle.battleMap == null || offhandSkill == null)
            {
                return;
            }

            UnitCtrlPlayer player = SceneType.battle.battleMap.playerUnitCtrl;
            if (player == null || player.isDestroy || player.isDie)
            {
                return;
            }

            if (Input.GetKey(g.data.globle.key.battleSkill1) && offhandSkill.IsCreate(false, null, true, true))
            {
                offhandSkill.Create(player.posiBullet.position, player.posiBullet.up, null, null, null);
            }
        }

        private static void OnOpenUIEnd(ETypeData e)
        {
            OpenUIEnd data = e.Cast<OpenUIEnd>();
            if (data.uiType.uiName != UIType.PlayerInfo.uiName)
            {
                return;
            }

            UIPlayerInfo ui = g.ui.GetUI<UIPlayerInfo>(UIType.PlayerInfo);
            if (ui == null)
            {
                return;
            }

            Transform imageRoot = ui.uiSkill.goSkillLeftRoot.transform.Find("Image");
            if (imageRoot == null)
            {
                return;
            }

            GameObject clonedButton = UnityEngine.Object.Instantiate(ui.btnClose.gameObject, imageRoot.parent);
            clonedButton.SetActive(true);
            Button button = clonedButton.GetComponent<Button>();
            if (button != null)
            {
                button.onClick.RemoveAllListeners();
                button.onClick.AddListener((Action)(() => UITipItem.AddTip("ApiProbe clicked")));
            }
        }

        private static void OnUnitHitDynIntHandler(ETypeData e)
        {
            UnitHitDynIntHandler data = e.Cast<UnitHitDynIntHandler>();
            if (data.hitUnit == null || data.dynV == null)
            {
                return;
            }

            data.dynV.baseValue = data.dynV.baseValue;
            data.dynV.ClearCall();
        }

        public static void ProbeEquipActions(string skillId)
        {
            g.world.playerUnit.CreateAction(new UnitActionMartialUnequip(default(MartialType), 0), false);
            if (!string.IsNullOrEmpty(skillId) && g.world.playerUnit.data.unitData.allActionMartial.ContainsKey(skillId))
            {
                g.world.playerUnit.CreateAction(new UnitActionMartialEquip(g.world.playerUnit.data.unitData.allActionMartial[skillId], 0), false);
            }
        }
    }
}
