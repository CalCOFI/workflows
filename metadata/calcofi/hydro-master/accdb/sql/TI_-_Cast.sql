-- query: TI - Cast
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, Cast.Order_Occ, Station_ID.St_Line, Cast.Sta_ID, Cast.Time, Cast.Cst_Cnt, Cast.Sta_Code, Cast.Date, Cast.Lat_Dec, Cast.Lon_Dec, Cast.St_Line, Cast.St_Station, Cast.Bottom_D
FROM Cast LEFT JOIN Station_ID ON Cast.Sta_ID = Station_ID.Sta_ID
GROUP BY Cast.Cruise, Cast.Order_Occ, Station_ID.St_Line, Cast.Sta_ID, Cast.Time, Cast.Cst_Cnt, Cast.Sta_Code, Cast.Date, Cast.Lat_Dec, Cast.Lon_Dec, Cast.St_Line, Cast.St_Station, Cast.Bottom_D
HAVING (((Cast.Sta_ID)="080.0 080.0") AND ((Cast.Sta_Code)="ST"));
