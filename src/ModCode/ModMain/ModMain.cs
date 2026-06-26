using System.Reflection;

/// <summary>
/// 当你手动修改了此命名空间，需要去模组编辑器修改对应的新命名空间，程序集也需要修改命名空间，否则DLL将加载失败！！！
/// </summary>
namespace MOD_h6Zv8g
{
    /// <summary>
    /// 此类是模组的主类
    /// </summary>
    public class ModMain
    {
        private static HarmonyLib.Harmony harmony;
        private DualWield.OffhandController offhandController;

        /// <summary>
        /// MOD初始化，进入游戏时会调用此函数
        /// </summary>
        public void Init()
        {
            DualWield.DualWieldLog.Info("FW-20260627-02 ModMain.Init entered. Assembly=MOD_h6Zv8g", true);

            if (harmony != null)
            {
                harmony.UnpatchSelf();
                harmony = null;
            }

            harmony = new HarmonyLib.Harmony("MOD_h6Zv8g");
            harmony.PatchAll(Assembly.GetExecutingAssembly());

            offhandController = new DualWield.OffhandController();
            offhandController.Init();

            DualWield.DualWieldLog.Info("FW-20260627-02 ModMain.Init completed.", false);
        }

        /// <summary>
        /// MOD销毁，回到主界面，会调用此函数并重新初始化MOD
        /// </summary>
        public void Destroy()
        {
            DualWield.DualWieldLog.Info("FW-20260627-02 ModMain.Destroy entered.", false);

            if (offhandController != null)
            {
                offhandController.Destroy();
                offhandController = null;
            }

            if (harmony != null)
            {
                harmony.UnpatchSelf();
                harmony = null;
            }
        }
    }
}
