/**
 * PxGameplayOptions.as
 *
 * Subscribes to the gameplay options event to grab items with a specific pattern and cache them into a data object.
 */
package PXC
{
    import Shared.AS3.Data.BSUIDataManager;
    import Shared.AS3.Data.FromClientDataEvent;

    public class PxGameplayOptions
    {
        // ----------------------------------------------------------------------------------------------------
        // Properties
        // ----------------------------------------------------------------------------------------------------

        public static const sVersion:String = "1.0.0";
        public var onDataChange:Function = null;
        private var sPattern:String;
        private var bMatchDescription:Boolean = false;
        private var bInitialized:Boolean = false;
        private var bHasReceivedValidData:Boolean = false;
        private var aDataMap:Object = {};
        private var aData:Array = [];

        // ----------------------------------------------------------------------------------------------------
        // Main Public Methods
        // ----------------------------------------------------------------------------------------------------

        /**
        * Constructor.
        */
        public function PxGameplayOptions()
        {
            super();
        }

        /**
        * Initialize and subscribe to game events.
        *
        * @param sPattern: String pattern to find in the PEO settings for this mod; Must not be null.
        * @param fCallBack: Function to call on data update; Ignored if null.
        * @param bMatchDescription: Pattern match the PEO entry description instead of name; Default is False.
        * @param bIsRegexPattern: Pattern string is a RegEx pattern and do not escape it; Default is False.
        */
        public function Initialize(sPattern:String, fCallBack:Function, bMatchDescription:Boolean = false, bIsRegexPattern:Boolean = false) : void
        {
            if (this.IsNullOrEmpty(sPattern))
            {
                trace("[PxGameplayOptions:Initialize] ERROR! Parameter 'sPattern' MUST not be null!");
                return
            }

            if (bInitialized)
                return;
            
            this.sPattern = bIsRegexPattern ? this.RegexEscape(sPattern) : sPattern;
            this.bMatchDescription = bMatchDescription;
            this.onDataChange = fCallBack;
            BSUIDataManager.Subscribe("PEOData",this.OnPEODataUpdate);
            BSUIDataManager.dispatchCustomEvent("SettingsPanel_OpenCategory",{"categoryID":0});
            trace("[PxGameplayOptions:Initialize] Pattern: " + sPattern);
            bInitialized = true;
        }

        /**
        * Unsubscribe to the engine events and clear object memory.
        */
        public function Dispose() : void
        {
            BSUIDataManager.Unsubscribe("PEOData", this.OnPEODataUpdate);
            onDataChange = null;
            aData.length = 0;
            aDataMap = {};
            bInitialized = false;
            bHasReceivedValidData = false;
        }

        // ----------------------------------------------------------------------------------------------------
        // Public Data Access Methods
        // ----------------------------------------------------------------------------------------------------

        /**
        * Gets individual data object that matches the passed name string.
        *
        * @param sName: PEO setting name; Null safe.
        * @return Found matching object; null if setting not found.
        */
        public function GetSettingObject(sName:String):Object
        {
            if (this.IsNullOrEmpty(sName))
                return null;

            return aDataMap[sName];
        }

        /**
        * Gets the string value property from the individual data object that matches the passed name string.
        *
        * @param sName: PEO setting name; Null safe.
        * @return String value for the found object; null if setting not found.
        */
        public function GetSettingValueString(sName:String) : String
        {
            var oSetting:Object = GetSettingObject(sName);
            return (oSetting != null) ? oSetting.sValue : null;
        }

        /**
        * Gets the int value property from the individual data object that matches the passed name string.
        *
        * @param sName: PEO setting name; Null safe.
        * @return Integer value for the found object; 0 if setting not found.
        */
        public function GetSettingValueInt(sName:String) : int
        {
            var oSetting:Object = GetSettingObject(sName);
            return (oSetting != null) ? oSetting.iValue : 0;
        }

        /**
        * Gets the bool value property from the individual data object that matches the passed name string.
        *
        * @param sName: PEO setting name; Null safe.
        * @return Boolean value for the found object; False if setting not found.
        */
        public function GetSettingValueBool(sName:String) : Boolean
        {
            var oSetting:Object = GetSettingObject(sName);
            return (oSetting != null) ? oSetting.bValue : false;
        }

        /**
        * Public access to the loaded data object.
        *
        * @return The full data object array.
        */
        public function get data() : Array
        {
            return aData;
        }

        /**
        * Validate data object has been loaded
        *
        * @return The boolean flag for valid PEO objects found and cached.
        */
        public function get isLoaded() : Boolean
        {
            return bHasReceivedValidData;
        }

        /**
        * Returns the full data object array as a formatted string for debugging.
        *
        * @return Formatted string of the data object array informatio and entries.
        */
        override public function toString():String
        {
            var sOutput:String = "";
            var i:int = 0;

            sOutput += "\r\n[Gameplay Options]\r\n";
            sOutput += "Pattern: " + sPattern + "\r\n";

            if (bMatchDescription)
            {
                sOutput += "Match Property: Description\r\n";
            }
            else
            {
                sOutput += "Match Property: Setting Name\r\n";
            }
            
            sOutput += "Matching Options: " + aData.length + "\r\n";
            sOutput += "\r\n====================\r\n\r\n";

            while (i < aData.length)
            {
                var oItem:Object = aData[i];
                sOutput += "sName: " + oItem.sName + "\r\n";
                sOutput += "sType: " + oItem.sType + "\r\n";
                sOutput += "iValue: " + oItem.iValue + "\r\n";
                sOutput += "sValue: " + oItem.sValue + "\r\n";
                sOutput += "bValue: " + oItem.bValue + "\r\n";
                sOutput += "--------------------\r\n\r\n";
                i++;
            }

            return sOutput;
        }

        // ----------------------------------------------------------------------------------------------------
        // Private Data Methods
        // ----------------------------------------------------------------------------------------------------

        /**
        * When the engine event data is recieved, parse the data that matches the configured pattern into a data object array.
        *
        * @param oFromClient: Object passed from the engine; Null safe.
        */
        private function OnPEODataUpdate(oFromClient:FromClientDataEvent) : void
        {
            if (oFromClient == null || oFromClient.data == null || oFromClient.data.aGeneralSettingsList == null)
                return;

            var iIndex:int = 0;
            var aList:Array = oFromClient.data.aGeneralSettingsList;
            while (iIndex < aList.length)
            {
                this.ResolvePEOItem(aList[iIndex]);
                iIndex++;
            }

            if (onDataChange != null)
                onDataChange();
        }

        /**
        * Gets the values for the passed PEO object; If it matches the configured pattern, add it to the data array or update existing value.
        *
        * @param oInput: Individual PEO object; Null safe.
        */
        private function ResolvePEOItem(oInput:Object) : void
        {
            if (oInput == null || this.IsNullOrEmpty(oInput.sText))
                return;

            var sMatchItem:String = bMatchDescription ? oInput.sDescription : oInput.sText;
            if (!this.IsRegexMatch(sMatchItem, sPattern))
                return;

            bHasReceivedValidData = true;
            var sName:String = oInput.sText;
            var iValue:int = int(oInput.stepperData.uIndex);
            var sValue:String = oInput.stepperData.aStepperOptions[oInput.stepperData.uIndex];
            var bValue:Boolean = oInput.checkBoxData.bChecked;
            var sType:String = "Float";

            if (oInput.uType == 3)
            {
                sType = "Bool";
                iValue = bValue ? 1 : 0;
                sValue = bValue ? oInput.checkBoxData.bOnCustomText : oInput.checkBoxData.bOffCustomText;
            }

            var oExisting:Object = aDataMap[sName];
            if (oExisting != null)
            {
                oExisting.sType = sType;
                oExisting.iValue = iValue;
                oExisting.sValue = sValue;
                oExisting.bValue = bValue;
            }
            else
            {
                oExisting = {
                    sName: sName,
                    sType: sType,
                    iValue: iValue,
                    sValue: sValue,
                    bValue: bValue
                };

                aDataMap[sName] = oExisting;
                aData.push(oExisting);
            }
        }

        // ----------------------------------------------------------------------------------------------------
        // Private Helper Methods
        // ----------------------------------------------------------------------------------------------------

        /**
        * Validates if the passed string is null or empty
        *
        * @param sValue: String to validate.
        * @return True if null or empty; False if not.
        */
        private function IsNullOrEmpty(sValue:String):Boolean
        {
            return sValue == null || sValue.length == 0;
        }

        /**
        * Escapes regex characters for use with a regex match
        *
        * @param sValue: String to escape; Null safe.
        * @return string with Regex operators escaped.
        */
        private function RegexEscape(sValue:String):String
        {
            if(this.IsNullOrEmpty(sValue))
                return null;

            return sValue.replace(/([.*+?^${}()|[\]\\])/g, "\\$1");
        }

        /**
        * Performes a regex match for the passed value and pattern.
        *
        * @param sValue: String to match against; Null safe.
        * @param sPattern: RegEx pattern; Null safe.
        * @return Boolean result of the regex match; False if input string and/or pattern are null or empty.
        */
        private function IsRegexMatch(sValue:String, sPattern:String):Boolean
        {
            if(this.IsNullOrEmpty(sValue) || this.IsNullOrEmpty(sPattern))
                return false;

            var rxRegex:RegExp = new RegExp(sPattern);
            return rxRegex.test(sValue);
        }
    }
}