-- query: Depth Data - 1 Stations
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Cruise, Cast.Sta_ID, Cast.Lat_Dec, Cast.Lon_Dec, Avg(Cast.Date) AS Date, Avg(Cast!Month+Day(Cast!Date)/31.5-1) AS Month, Avg(Bottle.Depthm) AS Depth, Avg(Bottle.STheta) AS Density, Avg(Bottle.T_degC) AS Temp, Avg(Bottle.Salnty) AS Sal, Avg(Chl.ChlorA) AS Chl, Avg(Nuts.PO4ug) AS PO4, Avg(Nuts.SiO3ug) AS SiO4, Avg(Nuts.NO2ug) AS NO2, Avg(Nuts.NO3ug) AS NO3, Avg(Bottle.O2ml_L) AS O2
FROM Cruises INNER JOIN (Cast INNER JOIN ((Bottle LEFT JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Bottle.Depthm)=200) AND ((Cruises.[Code-ST])="st") AND ((Cast.Sta_Code)="st"))
GROUP BY Cast.Year, Cast.Cruise, Cast.Sta_ID, Cast.Lat_Dec, Cast.Lon_Dec, Cast.Cast_ID
HAVING (((Cast.Cruise)>198400))
ORDER BY Cast.Year, Cast.Cruise;
