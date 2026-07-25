-- query: TI - Single Cruise Station Loc
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, Cast.Ship_Code, Cast.Sta_ID, Cast.Lon_Dec, Cast.Lat_Dec, Cast.Date
FROM Cast
WHERE (((Cast.Cruise)=198406));
