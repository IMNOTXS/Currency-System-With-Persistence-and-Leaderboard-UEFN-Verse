# Currency System with persistance and time leaderboard
The following has 3 Verse files:\
**1. currency_system.verse**\
**2. persistence_manager.verse**\
**3. time_leaderboard.verse**

Download them and copy paste it into your uefn project file. **Make sure they're named exactly the same FOR ALL FILES**. If not you must change its name the same as the class that you named the file. 


# Currency System

The currency system is custom currency. 
1. once you pasted the code and compiled it add it in the editor. in the "details" section set the "FPS_ToRefreshCurency" to 15.
2. in the "currencies data" add in 1 array element and set the "currencyID" to "gold" (write it down).
3. make 2 huds that displays the currency "currentAmoutHud" and "NotUIHUD" and set them inside the "currenciesdata".
4. The "ManagersData" is where you set the triggers and "CurrencyAction". once you set the trigger set the "currency action to either increment the currency or decrement and how much. You can add in as much "managers data".\
5. The "PRiceManagersData" is basicaly a shop for the currency. set the name of the "PriceManagerID" as whatever you like. Check the "With saving", add a buttons device and add and set the "Price Data".
6. in the "Price Data" set the currencyID to "Gold" this is **important**, then you can set the price of the item.
7. add in 2 new triggers called "Trigger_Cost_Item" and "Trigger_Activate_Item" and set them in the "ManagersTriggers" -> Trigger_cost. And "MainSuccessTriggers" -> Trigger_Activate_Item"



# Time LeaderBoard

The time leaderboard is already set. It already has the ui built in verse, you dont have to do anything other than adding it in the editor once you copy paste it to your verse file and compiled it. But make sure its "Enabled at Game start".
The purpose of this is that it will increment each second and saves it when the player leaves in the "Persistence Manager". So when the player rejoins it will load his seconds, minutes, hours. 


# Persistance manager

in this file you dont add it in the editor. Just copy and paste it into your file and compile. then it will save the currency and the leaderboard



