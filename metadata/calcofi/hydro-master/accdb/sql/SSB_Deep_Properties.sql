-- query: SSB Deep Properties
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, Avg(Cast.Date) AS Date, Avg(Cast!Month+Day(Cast!Date)/31.5-1) AS Month, Avg(Bottle.Depthm) AS AvgDepth, Avg(Bottle.T_degC) AS Temp, Avg(Bottle.Salnty) AS Sal, Avg(Bottle.STheta) AS Density, Avg(Bottle.O2ml_L) AS O2, Avg(Nuts.PO4ug) AS PO4, Avg(Nuts.SiO3ug) AS SiO4, Avg(Nuts.NO2ug) AS NO2, Avg(Nuts.NO3ug) AS NO3
FROM Cruises INNER JOIN ((Station_ID INNER JOIN Cast ON Station_ID.DBSta_ID = Cast.DbSta_ID) INNER JOIN ((Bottle LEFT JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Bottle.Depthm)>524) AND ((Bottle.RecInd)=3) AND ((Station_ID.Sta_ID)="081.8 046.9" Or (Station_ID.Sta_ID)="081.8 046.0"))
GROUP BY Cast.Cruise, Cast.Year
HAVING (((Cast.Year)>1986));
