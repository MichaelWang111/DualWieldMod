using System;
using UnityEngine;

namespace MOD_h6Zv8g.DualWield
{
    internal static class DualWieldLog
    {
        private const string Prefix = "[DualWieldMod]";

        public static void Info(string message, bool showTip = false)
        {
            string fullMessage = Prefix + " " + message;

            try
            {
                Debug.Log(fullMessage);
            }
            catch
            {
            }

            try
            {
                Console.WriteLine(fullMessage);
            }
            catch
            {
            }

            if (showTip)
            {
                ShowTip(fullMessage);
            }
        }

        private static void ShowTip(string message)
        {
            try
            {
                UITipItem.AddTip(message);
            }
            catch (Exception ex)
            {
                try
                {
                    Debug.Log(Prefix + " UITipItem.AddTip failed: " + ex.Message);
                }
                catch
                {
                }
            }
        }
    }
}
