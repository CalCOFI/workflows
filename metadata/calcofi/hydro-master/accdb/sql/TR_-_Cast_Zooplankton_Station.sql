-- query: TR - Cast & Zooplankton: Station
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cst_Cnt, Cast.Cruise, Cast.Sta_ID, Cast.Date, Cast.St_Line
FROM Cruises INNER JOIN (Cast LEFT JOIN Zooplankton ON Cast.Cruz_Sta = Zooplankton.Cruz_Sta) ON Cruises.Cruise = Cast.Cruise
WHERE (((Cast.Sta_Code)="st") AND ((Cruises.[Code-ST])="st"))
GROUP BY Cast.Cst_Cnt, Cast.Cruise, Cast.Sta_ID, Cast.Date, Cast.St_Line, Zooplankton.Cruz_Sta
HAVING (((Cast.Cruise) Between 198400 And 200900) AND ((Zooplankton.Cruz_Sta) Is Null));
