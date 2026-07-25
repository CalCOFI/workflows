-- query: TQ - BottomDepth_Vs_AvgBottomDepth
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, CurrentStations.Sta_ID, Cast.Cst_Cnt, Cast.Bottom_D, CurrentStations.Avg_Depth
FROM Cast INNER JOIN CurrentStations ON Cast.Sta_ID=CurrentStations.Sta_ID
WHERE (((Cast!Bottom_D)>(CurrentStations!Avg_Depth+500) Or (Cast!Bottom_D)<(CurrentStations!Avg_Depth-500)))
GROUP BY Cast.Cruise, CurrentStations.Sta_ID, Cast.Cst_Cnt, Cast.Bottom_D, CurrentStations.Avg_Depth
ORDER BY Cast.Cruise;
