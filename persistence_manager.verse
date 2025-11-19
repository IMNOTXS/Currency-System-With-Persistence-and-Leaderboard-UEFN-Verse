using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }

player_stats_table := struct<persistable>:
    Balances     : [string]int   # per-currency amounts
    TotalSeconds : int           # optional for your time leaderboard

var PlayerStatsMap : weak_map(player, player_stats_table) = map{}

Persistence_Manager := class():

    InitializePlayer(P:player):void =
        if (P.IsActive[] and not PlayerStatsMap[P]):
            if (set PlayerStatsMap[P] = player_stats_table{
                Balances := map{},
                TotalSeconds := 0
            }) {}
            Print("PM: created new player_stats_table")

    GetBalance(P:player, CurrencyID:string):int =
        if (Row := PlayerStatsMap[P]):
            if (V := Row.Balances[CurrencyID]): 
                return V
        return 0

    SetBalance(P:player, CurrencyID:string, Amount:int):void =
        if (Row := PlayerStatsMap[P]):
            # 1) copy balances to a mutable local
            var NB : [string]int = Row.Balances
            # 2) mutate the copy in a failure context
            if (set NB[CurrencyID] = Amount) {}
            # 3) rebuild the struct (structs are values) and write back
            NewRow := player_stats_table{
                Balances     := NB,
                TotalSeconds := Row.TotalSeconds
            }
            if (set PlayerStatsMap[P] = NewRow) {}
            Print("PM: SetBalance {CurrencyID} -> {Amount}")
        else:
            # first-time row
            NR := player_stats_table{ Balances := map{}, TotalSeconds := 0 }
            var NB : [string]int = NR.Balances
            if (set NB[CurrencyID] = Amount) {}
            NR2 := player_stats_table{
                Balances     := NB,
                TotalSeconds := NR.TotalSeconds
            }
            if (set PlayerStatsMap[P] = NR2) {}
            Print("PM: SetBalance (created row) {CurrencyID} -> {Amount}")


    GetTotalSeconds(P:player):int =
        if (Row := PlayerStatsMap[P]): 
            return Row.TotalSeconds
        return 0

    SetTotalSeconds(P:player, Secs:int):void =
        if (Row := PlayerStatsMap[P]):
            NewRow := player_stats_table{
                Balances     := Row.Balances,  # keep existing balances
                TotalSeconds := Secs           # updated seconds
            }
            if (set PlayerStatsMap[P] = NewRow) {}

