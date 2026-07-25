-- query: QC - BottomDepthCheck_AllValues
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, Cast.Cst_Cnt, Cast.Bottom_D, Cast.DbSta_ID, CurrentStations.Sta_ID, CurrentStations.Avg_Depth
FROM Cast INNER JOIN CurrentStations ON Cast.Sta_ID = CurrentStations.Sta_ID
GROUP BY Cast.Cruise, Cast.Cst_Cnt, Cast.Bottom_D, Cast.DbSta_ID, CurrentStations.Sta_ID, CurrentStations.Avg_Depth, Cast.Sta_Code, Cast.Year, Cast.St_Line
HAVING (((Cast.Cruise)=202111) AND ((Cast.Sta_Code)="st" Or (Cast.Sta_Code)="sco"))
ORDER BY Cast.DbSta_ID;
