
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors }
using { /Fortnite.com/UI }
using { /Verse.org/Assets }



LOOP_EXPIRE_TIME : float = 300.0
StringMessage<localizes>(Message:string):message= "{Message}"

currency_actions := enum{Increment, Decrement, Set}




agent_data := class:
    var CurrentCurrencyAmount : [string]int = map{}
    var CurrentPriceManagerData : []price_manager_data = array{}



price_data := class<concrete>:
    @editable
    CurrencyID : string = ""
    @editable
    Price : int = 0

price_manager_data := class<concrete>:
    @editable
    PriceManagerID : string = ""
    @editable
    WithSaving : logic = false
    @editable
    ButtonsDevice : []button_device = array{}
    @editable
    PriceData : []price_data = array{}
    @editable
    ManagersTriggers : []trigger_device = array{}
    @editable
    MainSuccessTriggers : []trigger_device = array{}

    # Add this:
    @editable
    InsufficientFundsHUD : hud_message_device = hud_message_device{}

    var MaybeMainDevice : ?currency_system = false
    


    OnBegin():void=
        for(ButtonDevice : ButtonsDevice):
            ButtonDevice.InteractedWithEvent.Subscribe(OnButtonClicked)


    # ---- price_manager_data ----
    OnButtonClicked(Agent:agent):void =
        if (P := player[Agent], MainDevice := MaybeMainDevice?, AgentData := MainDevice.AgentDataMap[P]):
            CanBuy := MainDevice.CheckPriceForMultipleCurrency(P, PriceData)
            HaveIt := MainDevice.CheckIfHave(P, Self)

            if (HaveIt = false):
                if (CanBuy = true):
                    # SUCCESS PATH: only fire these on success
                    for (MainSuccessTrigger : MainSuccessTriggers):
                        MainSuccessTrigger.Trigger(Agent)
                    for (ManagerTrigger : ManagersTriggers):
                        ManagerTrigger.Trigger(Agent)

                    if (WithSaving = true):
                        set AgentData.CurrentPriceManagerData += array{Self}
                else:
                    # FAIL PATH: show “not enough money”
                    InsufficientFundsHUD.Show(P)
            else:
                # Already owned; whatever behavior you want (keep as-is)
                for (MainSuccessTrigger : MainSuccessTriggers):
                    MainSuccessTrigger.Trigger(Agent)



manager_data := class<concrete>:
    @editable
    Trigger : trigger_device = trigger_device{}
    @editable
    CurrencyAction : currency_actions = currency_actions.Increment
    @editable
    HowMuch : int = 50

    var MaybeMainDevice : ?currency_data = false

    OnBegin():void=
        Trigger.TriggeredEvent.Subscribe(OnTriggerTriggered)

    OnTriggerTriggered(MaybeAgent:?agent):void =
        if (Agent := MaybeAgent?, P := player[Agent]):
            if (MainDevice := MaybeMainDevice?, CurrencySystem := MainDevice.MaybeMainDevice?):
                CurrencySystem.CurrencyAction(P, CurrencyAction, MainDevice.CurrencyID, HowMuch)



currency_data := class<concrete>:
    @editable
    CurrencyID : string = ""
    @editable
    CurrentAmountHUD : hud_message_device = hud_message_device{}
    @editable
    NotiHUD : hud_message_device = hud_message_device{}
    @editable
    ManagersData : []manager_data = array{}

    var MaybeMainDevice : ?currency_system = false

    OnBegin():void=
        for(ManagerData : ManagersData):
            set ManagerData.MaybeMainDevice = option{Self}
            ManagerData.OnBegin()


currency_system := class(creative_device):


    Persistence : Persistence_Manager = Persistence_Manager{}

        # Per-player canvas and a per-player, per-currency text block
    var BalanceCanvasPerPlayer : [player]canvas = map{}
    var BalanceTextPerPlayer   : [player][string]text_block = map{}


    var DisplayedAmountPerPlayer : [player][string]int   = map{}
    var IsAnimatingPerPlayer     : [player][string]logic = map{}
    


    @editable
    FPS_ToRefreshCurrency : float = 10.0
    @editable
    CurrenciesData : []currency_data = array{}
    @editable
    PriceManagersData : []price_manager_data = array{}


    var AgentDataMap : [player]agent_data = map{}

    OnBegin<override>()<suspends>:void=
       spawn{SetTextInAllCurrencies()}

        for(CurrenctData : CurrenciesData):
            set CurrenctData.MaybeMainDevice = option{Self}
            CurrenctData.OnBegin()

        for(PriceManagerData : PriceManagersData):
            set PriceManagerData.MaybeMainDevice = option{Self}
            PriceManagerData.OnBegin()


        for(AllPlayers : GetPlayspace().GetPlayers(), Player := player[AllPlayers]):
            OnPlayerJoined(Player)

        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerJoined)

    AnimateCurrencyDisplay(P:player, CurrencyID:string, From:int, To:int)<suspends>:void =
        if (From = To): 
            return

        # mark animating
        var flags:[string]logic = map{}
        if (F := IsAnimatingPerPlayer[P]):
            set flags = F
        if (set flags[CurrencyID] = true) {}
        if (set IsAnimatingPerPlayer[P] = flags) {}

        # duration scales a bit with delta
        Delta:int = if (To >= From) then (To - From) else (From - To)
        var Duration:float =
            if (Delta <= 50) then 0.25
            else if (Delta <= 500) then 0.35
            else 0.50

        Steps:int = 15
        StepTime:float = Duration / 15.0

        if (TextMap := BalanceTextPerPlayer[P], TB := TextMap[CurrencyID]):
            # --- integer tween without division ---
            var Diff:int  = To - From
            var Sign:int  = if (Diff >= 0) then 1 else -1
            var Mag:int   = if (Diff >= 0) then Diff else -Diff   # absolute
            var Cur:int   = From
            var Carry:int = 0

            for (i := 1 .. Steps):
                set Carry += Mag

                # drain carry into whole-step increments (no division)
                loop:
                    if (Carry < Steps):
                        break
                    set Cur += Sign
                    set Carry -= Steps

                TB.SetText(StringMessage(DoFormatNumber(Cur)))
                var disp:[string]int = map{}
                if (D := DisplayedAmountPerPlayer[P]):
                     set disp = D
                if (set disp[CurrencyID] = Cur) {}
                if (set DisplayedAmountPerPlayer[P] = disp) {}

                Sleep(StepTime)


            # snap to exact final
            TB.SetText(StringMessage(DoFormatNumber(To)))
            var disp2:[string]int = map{}
            if (D2 := DisplayedAmountPerPlayer[P]):
                set disp2 = D2
            if (set disp2[CurrencyID] = To) {}
            if (set DisplayedAmountPerPlayer[P] = disp2) {}

        # clear animating flag
        var flags2:[string]logic = map{}
        if (F2 := IsAnimatingPerPlayer[P]):
            set flags2 = F2
        if (set flags2[CurrencyID] = false) {}
        if (set IsAnimatingPerPlayer[P] = flags2) {}




        
    OnPlayerJoined(Player:player):void =
        Persistence.InitializePlayer(Player)   # <— ensure a persistent row is bound

        if:
            not AgentDataMap[Player]
            set AgentDataMap[Player] = agent_data{}
            AgentData := AgentDataMap[Player]
        then:
            # start with 0s so HUD shows something
            for (CD : CurrenciesData):
                if (set AgentData.CurrentCurrencyAmount[CD.CurrencyID] = 0) {}

            # now load saved amounts and apply
            for (CD : CurrenciesData):
                Saved := Persistence.GetBalance(Player, CD.CurrencyID)
                if (set AgentData.CurrentCurrencyAmount[CD.CurrencyID] = Saved) {}

        EnsureBalanceUI(Player)

        # seed Displayed with the saved values so first render is correct
        var Disp:[string]int = map{}
        if (A := AgentDataMap[Player]):
            for (CD : CurrenciesData):
                var v:int = 0
                if (x := A.CurrentCurrencyAmount[CD.CurrencyID]):
                    set v = x
                if (set Disp[CD.CurrencyID] = v) {}
        if (set DisplayedAmountPerPlayer[Player] = Disp) {}





    LoadBalancesAfterBind(P:player)<suspends>:void =
        Sleep(0.25)  # short delay for hydration

        if (A := AgentDataMap[P]):
            for (CD : CurrenciesData):
                Saved := Persistence.GetBalance(P, CD.CurrencyID)
                if (set A.CurrentCurrencyAmount[CD.CurrencyID] = Saved) {}
                Print("Loaded balance for {CD.CurrencyID}: {Saved}")
            spawn { BringHudToFrontFor(P, 1.0) }


    # Use player everywhere for lookups
    CurrencyAction(Player:player, ActionType:currency_actions, CurrencyID:string, IntValue:int):void =
        if (AgentData := AgentDataMap[Player]):

            # capture "from" before we mutate
            var From:int = 0
            if (v := AgentData.CurrentCurrencyAmount[CurrencyID]): 
                set From = v

            CurrencyData := GetCurrencyData(CurrencyID)
            case (ActionType):
                currency_actions.Increment =>
                    if (set AgentData.CurrentCurrencyAmount[CurrencyID] += IntValue) {}
                    CurrencyData.NotiHUD.SetText(StringMessage("+{IntValue}"))
                    CurrencyData.NotiHUD.Show(Player)

                currency_actions.Decrement =>
                    if (set AgentData.CurrentCurrencyAmount[CurrencyID] -= IntValue) {}

                currency_actions.Set =>
                    if (set AgentData.CurrentCurrencyAmount[CurrencyID] = IntValue) {}

            if (AgentData.CurrentCurrencyAmount[CurrencyID] <= 0):
                if (set AgentData.CurrentCurrencyAmount[CurrencyID] = 0) {}

            # persist
            var Final:int = 0
            if (V := AgentData.CurrentCurrencyAmount[CurrencyID]): 
                set Final = V
            Persistence.SetBalance(Player, CurrencyID, Final)

            # animate "From -> Final"
            spawn { AnimateCurrencyDisplay(Player, CurrencyID, From, Final) }



    GetCurrencyData(CurrencyID:string):currency_data=
        for(CurrencyData : CurrenciesData):
            if(CurrencyData.CurrencyID = CurrencyID):
                return CurrencyData

        return currency_data{}


    CheckIfHave(Player:player, PriceManagerData:price_manager_data):logic =
        if (AgentData := AgentDataMap[Player]):
            for (AgentPMD : AgentData.CurrentPriceManagerData):
                if (AgentPMD.PriceManagerID = PriceManagerData.PriceManagerID):
                    return true
        return false


    # Does this player have enough for one price entry?
    # Pure (no decides): returns whether Player can afford the set of prices.
   # Pure (no <decides>): returns whether Player can afford all prices in PricesData.
    CheckPriceForMultipleCurrency(Player:player, PricesData:[]price_data):logic =
        # Bind AgentData in a failure context first (allowed in if-conditions)
        if (A := AgentDataMap[Player]):
            var Needed:int = PricesData.Length - 1
            var Got:int = -1

            for (PD : PricesData):
                # Count only when the currency exists AND is enough
                if (Amount := A.CurrentCurrencyAmount[PD.CurrencyID]):
                    if (Amount >= PD.Price):
                        set Got += 1

            # Be explicit: return true/false, not a boolean expression
            if (Got >= Needed):
                return true
            return false

        # No data for this player => cannot afford
        return false


    SetTextInAllCurrencies()<suspends>:void =
        var CURRENT_LOOP_TIME:float = 0.0
        Sleep(1.0)
        loop:
            Sleep(1.0 / FPS_ToRefreshCurrency)
            set CURRENT_LOOP_TIME += 1.0 / FPS_ToRefreshCurrency

            for (P : GetPlayspace().GetPlayers()):
                EnsureBalanceUI(P)

                if (AgentData := AgentDataMap[P]):
                    if (TextMap := BalanceTextPerPlayer[P]):
                        for (CD : CurrenciesData):
                            # true amount
                            var Amount:int = 0
                            if (Amt := AgentData.CurrentCurrencyAmount[CD.CurrencyID]):
                                set Amount = Amt

                            # skip if animating
                            var animating:logic = false
                            if (M := IsAnimatingPerPlayer[P]):
                                if (flag := M[CD.CurrencyID]): 
                                    set animating = flag

                            if (animating = false):
                                if (TB := TextMap[CD.CurrencyID]):
                                    TB.SetText(StringMessage(DoFormatNumber(Amount)))




            if (CURRENT_LOOP_TIME >= LOOP_EXPIRE_TIME):
                spawn { SetTextInAllCurrencies() }
                Sleep(0.0)
                break


    DoFormatNumber(NumberToFormat:int):string=
        ConvertedString := ToString(NumberToFormat)
        var ReturnString : string = ""
        for(Index := 0..ConvertedString.Length-1):
            if(Mod[ConvertedString.Length - Index, 3] = 0 and Index<> 0):
                set ReturnString = ReturnString + ","
            if(Char:=ConvertedString[Index]):
                set ReturnString = ReturnString + ToString(Char)

        return ReturnString

    BringHudToFrontFor(Player:player, Seconds:float)<suspends>:void =
        var remaining:float = Seconds
        loop:
            if (remaining <= 0.0):
                break

            if (PlayerUI := GetPlayerUI[Player], C := BalanceCanvasPerPlayer[Player]):
                PlayerUI.RemoveWidget(C)
                PlayerUI.AddWidget(C, player_ui_slot{ InputMode := ui_input_mode.None })

            Sleep(0.25)
            set remaining -= 0.25


   EnsureBalanceUI(Player:player):void =
    if (BalanceCanvasPerPlayer[Player]):
         return

    var slots : []canvas_slot = array{}
    var TextMap : [string]text_block = map{}
    var row:int = 0

    AnchorLeftCenter := anchors{ Minimum := vector2{X:=0.0,Y:=0.5}, Maximum := vector2{X:=0.0,Y:=0.5} }

    # 1) Frame as background (ZOrder 0)
    FrameBlock : texture_block =
        texture_block{
            DefaultImage := UI.frameimg,                     # <- pick any /Fortnite.com/UI image you like
            DefaultDesiredSize := vector2{ X := 420.0, Y := 130.0 }
        }

    set slots += array{
        canvas_slot:
            Anchors := AnchorLeftCenter
            Offsets := margin{ Top := 230.0, Left := 30.0, Right := 0.0, Bottom := 0.0 }
            Alignment := vector2{ X := 0.0, Y := 0.5 }
            SizeToContent := true
            ZOrder := 0
            Widget := FrameBlock                                # <- use the same name you declared
    }

    # 2) Text rows (ZOrder 100)
    for (CD : CurrenciesData):
        TB : text_block =
            text_block{
                DefaultText := StringMessage("0"),
                DefaultTextColor := NamedColors.White,
                DefaultJustification := text_justification.Right
            }

        set slots += array{
            canvas_slot:
                Anchors := AnchorLeftCenter
                Offsets := margin{ Top := 220.0 + row*28.0, Left := 180.0, Right := 0.0, Bottom := 0.0 }
                Alignment := vector2{ X := 0.0, Y := 0.5 }
                SizeToContent := true
                ZOrder := 100
                Widget := TB
        }

        if (set TextMap[CD.CurrencyID] = TB) {}
        set row += 1

    C:canvas = canvas{ Slots := slots }

    if (PlayerUI := GetPlayerUI[Player]):
        PlayerUI.AddWidget(C, player_ui_slot{ InputMode := ui_input_mode.None })
        spawn { BringHudToFrontFor(Player, 3.0) }

    if (set BalanceCanvasPerPlayer[Player] = C) {}
    if (set BalanceTextPerPlayer[Player]   = TextMap) {}