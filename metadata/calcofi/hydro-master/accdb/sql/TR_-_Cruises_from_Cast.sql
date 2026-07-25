-- query: TR - Cruises from Cast
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, Cast.Ship_Code, Count(Cast.Sta_ID) AS NO_Stations, Min(Cast.Date) AS From, Max(Cast.Date) AS To
FROM Cast
GROUP BY Cast.Cruise, Cast.Ship_Code
ORDER BY Cast.Cruise, Cast.Ship_Code;
