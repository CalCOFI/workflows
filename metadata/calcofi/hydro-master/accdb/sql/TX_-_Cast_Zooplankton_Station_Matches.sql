-- query: TX - Cast & Zooplankton: Station Matches
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cst_Cnt, Cast.Cruise, Cast.Sta_ID, Cast.Date, Cast.Time, [Date]+[Time] AS DateTime, Cast.Month, Cast.Lat_Dec, Cast.Lon_Dec, Cast.Sta_Code
FROM Cruises INNER JOIN (Cast LEFT JOIN Zooplankton ON Cast.Cruz_Sta = Zooplankton.Cruz_Sta) ON Cruises.Cruise = Cast.Cruise
WHERE (((Cruises.[Code-ST])="st"))
GROUP BY Cast.Cst_Cnt, Cast.Cruise, Cast.Sta_ID, Cast.Date, Cast.Time, Cast.Month, Cast.Lat_Dec, Cast.Lon_Dec, Cast.Sta_Code
HAVING (((Cast.Cruise)>198312) AND ((Cast.Sta_Code)="sco" Or (Cast.Sta_Code)="st"));
