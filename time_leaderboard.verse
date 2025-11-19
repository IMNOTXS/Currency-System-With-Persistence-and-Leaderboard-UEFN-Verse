using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Colors }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/UI }




time_leaderboard := class(creative_device):

    # ------------------ PERSISTENCE ------------------
    # Per-player persistent record

    # DO NOT move/rename this map or the save_data class once live
    # ------------------ PERSISTENCE ------------------

    Persistence : Persistence_Manager = Persistence_Manager{}
    





    # ------------------ UI CONFIG ------------------
    Anchor : anchors = anchors{ Minimum := vector2{X:=1.0, Y:=0.0}, Maximum := vector2{X:=1.0, Y:=0.0} }
    PanelOffset : margin = margin{ Top := 60.0, Left := -20.0, Right := 0.0, Bottom := 0.0 }
    RowHeight : float = 28.0
    PanelWidth : float = 440.0

    # ------------------ STATE ------------------
    var SecondsPlayed : [player]int = map{}
    var OrdinalByPlayer : [player]int = map{}
    var NextOrdinal : int = 1

    var CanvasByViewer : [player]canvas = map{}
    var RowsByViewer   : [player][]text_block = map{}

    # ------------------ LIFECYCLE ------------------
    OnBegin<override>()<suspends>:void =
        spawn { TickTimeAndUI() }

        for (A : GetPlayspace().GetPlayers()):
            if (P := player[A]):
                OnPlayerAdded(P)

        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)
        GetPlayspace().PlayerRemovedEvent().Subscribe(OnPlayerRemoved)

    OnPlayerAdded(P:player):void =
        if (not OrdinalByPlayer[P]):
            if (set OrdinalByPlayer[P] = NextOrdinal) {}
            set NextOrdinal += 1

        # Load from persistent store
        var saved:int = Persistence.GetTotalSeconds(P)
        if (set SecondsPlayed[P] = saved) {}

        EnsureUI(P)

    OnPlayerRemoved(P:player):void =
        if (T := SecondsPlayed[P]):
            Persistence.SetTotalSeconds(P, T)

        if (C := CanvasByViewer[P]):
            if (PUI := GetPlayerUI[P]):   # <-- rename
                PUI.RemoveWidget(C)       # <-- use PUI
        if (set CanvasByViewer[P] = canvas{}) {}
        if (set RowsByViewer[P] = array{}) {}


    # ------------------ TICK + UI REFRESH ------------------
    TickTimeAndUI()<suspends>:void =
        loop:
            Sleep(1.0)
            for (A : GetPlayspace().GetPlayers()):
                if (P := player[A]):
                    var T:int = 0
                    if (Old := SecondsPlayed[P]):
                        set T = Old + 1
                    else:
                        set T = 1
                    if (set SecondsPlayed[P] = T) {}
                    # Persist each second (you can throttle to every 5–10s if you want)
                    Persistence.SetTotalSeconds(P, T)

            TopMsgs := ComputeTop3Labels()
            PushLabelsToAllViewers(TopMsgs)

    # ------------------ UI BUILD ------------------
    EnsureUI(Viewer:player):void =
        if (CanvasByViewer[Viewer]):
            return

        var slots : []canvas_slot = array{}
        var rows  : []text_block = array{}

        Title : text_block =
            text_block{
                DefaultText := StringMessage("Top Time Played Leaderboard"),
                DefaultTextColor := NamedColors.Black,
                DefaultJustification := text_justification.Center
            }
        set slots += array{
            canvas_slot:
                Anchors := Anchor
                Offsets := margin{ Top := PanelOffset.Top, Left := PanelOffset.Left, Right := 0.0, Bottom := 0.0 }
                Alignment := vector2{ X := 1.0, Y := 0.0 }
                SizeToContent := true
                ZOrder := 50
                Widget := Title
        }

        for (i := 0..2):
            TB : text_block =
                text_block{
                    DefaultText := StringMessage("…"),
                    DefaultTextColor := NamedColors.White,
                    DefaultJustification := text_justification.Left
                }
            set rows += array{ TB }
            set slots += array{
                canvas_slot:
                    Anchors := Anchor
                    Offsets := margin{ Top := PanelOffset.Top + 34.0 + i*RowHeight, Left := PanelOffset.Left, Right := 0.0, Bottom := 0.0 }
                    Alignment := vector2{ X := 1.0, Y := 0.0 }
                    SizeToContent := true
                    ZOrder := 50
                    Widget := TB
            }

        C : canvas = canvas{ Slots := slots }

        if (PlayerUI := GetPlayerUI[Viewer]):
            PlayerUI.AddWidget(C, player_ui_slot{ InputMode := ui_input_mode.None })

        if (set CanvasByViewer[Viewer] = C) {}
        if (set RowsByViewer[Viewer]   = rows) {}

    # ------------------ LABEL HELPERS ------------------
    RowMsg<localizes>(Rank:int, A:agent, T:string):message = "{Rank}. {A} — {T}"
    EmptyRowMsg<localizes>(Rank:int):message = "{Rank}. Not enough players"

    # ------------------ RANKING ------------------
    ComputeTop3Labels():[]message =
        var used   : [player]logic = map{}
        var labels : []message = array{}
        var players : []player = array{}

        for (A : GetPlayspace().GetPlayers()):
            if (P := player[A]):
                set players += array{ P }

        for (rank := 1..3):
            var bestIdx:int = -1
            var bestT  :int = -1

            for (i := 0..players.Length-1):
                if (Pi := players[i]):
                    if (not used[Pi]):
                        var t:int = 0
                        if (TT := SecondsPlayed[Pi]):
                            set t = TT
                        if (t > bestT):
                            set bestT = t
                            set bestIdx = i

            if (bestIdx >= 0):
                if (BP := players[bestIdx]):
                    if (set used[BP] = true) {}
                    set labels += array{ RowMsg(rank, BP, FormatTime(bestT)) }
                else:
                    set labels += array{ EmptyRowMsg(rank) }
            else:
                set labels += array{ EmptyRowMsg(rank) }

        return labels

    PushLabelsToAllViewers(Labels:[]message):void =
        var viewers : []player = array{}
        for (A : GetPlayspace().GetPlayers()):
            if (V := player[A]):
                set viewers += array{ V }

        for (Viewer : viewers):
            if (rows := RowsByViewer[Viewer]):
                for (i := 0..Labels.Length-1):
                    if (i < rows.Length):
                        if (TB := rows[i], L := Labels[i]):
                            if (i = 0):
                                TB.SetTextColor(NamedColors.Gold)
                            else if (i = 1):
                                TB.SetTextColor(color{R:=0.75, G:=0.75, B:=0.8})
                            else if (i = 2):
                                TB.SetTextColor(color{R:=0.8, G:=0.5, B:=0.2})
                            else:
                                TB.SetTextColor(NamedColors.White)
                            TB.SetText(L)

    # ------------------ TIME FORMAT ------------------
    FormatTime(Secs:int):string =
        var s:int = Secs
        var m:int = 0
        loop:
            if (s < 60):
                break
            set s -= 60
            set m += 1
        ms : string =
            if (s < 10):
                "{m}:0{s}"
            else:
                "{m}:{s}"
        return ms
