-- query: TQ - StationNameChecker
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cst_Cnt, Cast.Cast_ID, Cast.Cruise_ID, Cast.Cruise, Cast.Sta_ID, Cast.Rpt_Line, Cast.Rpt_Sta, Cast.St_Line, Cast.St_Station, Cast.Cruz_Sta, Cast.DbSta_ID, Cast.Sta_Code
FROM Cast LEFT JOIN CurrentStations ON Cast.Sta_ID = CurrentStations.Sta_ID
WHERE (((Cast.Sta_Code)="st" Or (Cast.Sta_Code)="sco"))
GROUP BY Cast.Cst_Cnt, Cast.Cast_ID, Cast.Cruise_ID, Cast.Cruise, Cast.Sta_ID, Cast.Rpt_Line, Cast.Rpt_Sta, Cast.St_Line, Cast.St_Station, Cast.Cruz_Sta, Cast.DbSta_ID, Cast.Sta_Code, CurrentStations.Sta_ID, Cast.Year
HAVING (((Cast.Rpt_Line)>"76.6" And (Cast.Rpt_Line)<"93.4") AND ((CurrentStations.Sta_ID) Is Null) AND ((Cast.Year)>2000));
