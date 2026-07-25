-- query: TR - Keeling_DIC & Cast: Cruise-St_ID
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT [Keeling DIC].ID, [Keeling DIC].Cruise, [Keeling DIC].Station_ID, [Keeling DIC].Notes, Avg(Cast.Date) AS Cast_Date, [Keeling DIC].Date AS DIC_Date, [Keeling DIC].Lat_dec AS DIC_Lat, [Keeling DIC].Long_dec AS DIC_Long, Avg(Cast.Lat_Dec) AS Cast_Lat, Avg(Cast.Lon_Dec) AS Cast_Long, ([DIC_Date]-[Cast_Date])*0.999 AS Date_Test, ([DIC_Lat]-[Cast_Lat]) AS Lat_Test, [DIC_Long]+[Cast_Long] AS Long_Test
FROM Cast RIGHT JOIN [Keeling DIC] ON (Cast.Cruise = [Keeling DIC].Cruise) AND (Cast.Sta_ID = [Keeling DIC].Station_ID)
GROUP BY [Keeling DIC].ID, [Keeling DIC].Cruise, [Keeling DIC].Station_ID, [Keeling DIC].Notes, [Keeling DIC].Date, [Keeling DIC].Lat_dec, [Keeling DIC].Long_dec
HAVING ((([Keeling DIC].Lat_dec) Is Not Null))
ORDER BY [Keeling DIC].ID;
