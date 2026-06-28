using System;
using EGameTypeData;
using UnityEngine;
using UnityEngine.UI;
using UnhollowerBaseLib;

namespace MOD_h6Zv8g.DualWield
{
    internal sealed class OffhandSelectionUiController
    {
        private const string ButtonName = "DualWieldOffhandButton";
        private const string EmptyTooltip = "副手为空";

        private Il2CppSystem.Action<ETypeData> onOpenUiEnd;

        public void Init()
        {
            DualWieldLog.Info("OffhandSelectionUiController.Init registering UI events.", false);
            onOpenUiEnd = (Il2CppSystem.Action<ETypeData>)OnOpenUiEnd;
            g.events.On(EGameType.OpenUIEnd, onOpenUiEnd, 0, false);
        }

        public void Destroy()
        {
            DualWieldLog.Info("OffhandSelectionUiController.Destroy unregistering UI events.", false);
            if (onOpenUiEnd != null)
            {
                g.events.Off(EGameType.OpenUIEnd, onOpenUiEnd);
                onOpenUiEnd = null;
            }
        }

        private void OnOpenUiEnd(ETypeData e)
        {
            try
            {
                OpenUIEnd data = e.Cast<OpenUIEnd>();
                if (data == null || data.uiType.uiName != UIType.PlayerInfo.uiName)
                {
                    return;
                }

                InjectPlayerInfoButton();
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("Offhand UI injection failed: " + ex, true);
            }
        }

        private void InjectPlayerInfoButton()
        {
            UIPlayerInfo ui = g.ui.GetUI<UIPlayerInfo>(UIType.PlayerInfo);
            if (ui == null || ui.uiSkill == null || ui.uiSkill.goSkillLeftRoot == null || ui.btnClose == null)
            {
                return;
            }

            Transform imageRoot = ui.uiSkill.goSkillLeftRoot.transform.Find("Image");
            if (imageRoot == null || imageRoot.parent == null)
            {
                return;
            }

            Transform existing = imageRoot.parent.Find(ButtonName);
            if (existing != null)
            {
                UnityEngine.Object.Destroy(existing.gameObject);
            }

            GameObject buttonObject = UnityEngine.Object.Instantiate(ui.btnClose.gameObject, imageRoot.parent);
            buttonObject.SetActive(true);
            buttonObject.name = ButtonName;
            buttonObject.transform.localPosition = new Vector3(imageRoot.localPosition.x, imageRoot.localPosition.y + 60f, imageRoot.localPosition.z);
            buttonObject.transform.localScale = new Vector3(0.7f, 0.7f, 1f);

            Image iconImage = buttonObject.GetComponentInChildren<Image>();
            GameObject coverObject = UnityEngine.Object.Instantiate(imageRoot.gameObject, buttonObject.transform);
            for (int i = coverObject.transform.childCount - 1; i >= 0; i--)
            {
                UnityEngine.Object.Destroy(coverObject.transform.GetChild(i).gameObject);
            }

            coverObject.SetActive(true);
            coverObject.name = "DualWieldOffhandCover";
            coverObject.transform.localPosition = Vector3.zero;
            coverObject.transform.localScale = new Vector3(0.9f, 0.9f, 1f);
            Image bgImage = coverObject.GetComponent<Image>();

            UISkyTipEffect tip = buttonObject.GetComponent<UISkyTipEffect>();
            if (tip == null)
            {
                tip = buttonObject.AddComponent<UISkyTipEffect>();
            }

            UpdateButtonVisual(iconImage, bgImage, tip);

            Button button = buttonObject.GetComponent<Button>();
            if (button != null)
            {
                button.onClick.RemoveAllListeners();
                button.onClick.AddListener((Action)(() => OnClickToggleOffhand(iconImage, bgImage, tip)));
            }

            DualWieldLog.Info("Offhand selection button injected into PlayerInfo skill UI.", false);
        }

        private void OnClickToggleOffhand(Image iconImage, Image bgImage, UISkyTipEffect tip)
        {
            string mainSkillId = g.world.playerUnit.data.unitData.skillLeft;
            string currentOffhandSkillId = DualWieldSaveStore.OffhandSkillId;
            var allMartial = g.world.playerUnit.data.unitData.allActionMartial;

            if (string.IsNullOrEmpty(mainSkillId))
            {
                if (string.IsNullOrEmpty(currentOffhandSkillId))
                {
                    DualWieldLog.Info("Offhand selection skipped: no current main normal attack or saved offhand.", true);
                    return;
                }

                DualWieldSaveStore.ClearOffhandSkillId("player-info-button-clear");
                UpdateButtonVisual(iconImage, bgImage, tip);
                DualWieldLog.Info("Offhand cleared from selection button.", true);
                return;
            }

            if (allMartial == null || !allMartial.ContainsKey(mainSkillId))
            {
                DualWieldLog.Info("Offhand selection skipped: main normal attack not learned: " + mainSkillId, true);
                return;
            }

            if (mainSkillId == currentOffhandSkillId)
            {
                DualWieldSaveStore.ClearOffhandSkillId("player-info-button-toggle-off");
                UpdateButtonVisual(iconImage, bgImage, tip);
                DualWieldLog.Info("Offhand cleared by clicking current offhand. skillId=" + mainSkillId, true);
                return;
            }

            DualWieldSaveStore.SetOffhandSkillId(mainSkillId, "player-info-button");
            UnequipMainNormalAttack();
            UpdateButtonVisual(iconImage, bgImage, tip);
            DualWieldLog.Info("Offhand selected from current main normal attack and main unequipped. skillId=" + mainSkillId, true);
        }

        private void UpdateButtonVisual(Image iconImage, Image bgImage, UISkyTipEffect tip)
        {
            DualWieldSaveStore.EnsureLoaded();
            string skillId = DualWieldSaveStore.OffhandSkillId;
            var allMartial = g.world.playerUnit.data.unitData.allActionMartial;
            if (!string.IsNullOrEmpty(skillId) && allMartial != null && allMartial.ContainsKey(skillId))
            {
                UIIconTool.PropsInfoDataBase propsInfoBase = allMartial[skillId].data.propsInfoBase;
                ConfBattleSkillAttackItem config = g.conf.battleSkillAttack.GetItem(propsInfoBase.baseID);
                if (iconImage != null && config != null)
                {
                    iconImage.overrideSprite = SpriteTool.GetSprite("CommonSkillIcon", config.icon);
                }

                if (bgImage != null)
                {
                    bgImage.overrideSprite = SpriteTool.GetMartialBG(propsInfoBase.level);
                }

                if (tip != null)
                {
                    tip.InitData(BuildSkillTooltip(propsInfoBase, config), default(Vector3));
                }
                return;
            }

            if (iconImage != null)
            {
                iconImage.overrideSprite = null;
            }

            if (bgImage != null)
            {
                bgImage.overrideSprite = null;
            }

            if (tip != null)
            {
                tip.InitData(EmptyTooltip, default(Vector3));
            }
        }

        private void UnequipMainNormalAttack()
        {
            try
            {
                g.world.playerUnit.CreateAction(new UnitActionMartialUnequip((MartialType)1, 0), false);
            }
            catch (Exception ex)
            {
                DualWieldLog.Info("Main normal attack unequip failed after offhand selection: " + ex, true);
            }
        }

        private string BuildSkillTooltip(UIIconTool.PropsInfoDataBase propsInfoBase, ConfBattleSkillAttackItem config)
        {
            string name = propsInfoBase != null ? propsInfoBase.name : string.Empty;
            if (string.IsNullOrEmpty(name) && config != null)
            {
                name = ResolveText(config.name);
            }

            string desc = config != null ? ResolveText(config.desc) : string.Empty;
            if (string.IsNullOrEmpty(desc) || desc == "0")
            {
                return string.IsNullOrEmpty(name) ? EmptyTooltip : name;
            }

            if (string.IsNullOrEmpty(name))
            {
                return desc;
            }

            return name + "\n" + desc;
        }

        private string ResolveText(string keyOrText)
        {
            if (string.IsNullOrEmpty(keyOrText) || keyOrText == "0")
            {
                return string.Empty;
            }

            try
            {
                string text = GameTool.LS(keyOrText);
                return string.IsNullOrEmpty(text) ? keyOrText : text;
            }
            catch
            {
                return keyOrText;
            }
        }
    }
}
