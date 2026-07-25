-- query: TV - Deep Properties
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Cruise, Avg(Cast.Date) AS Date, Avg(Cast.St_Line) AS AvgLine, Avg(Cast.St_Station) AS AvgStation, Count(Bottle.Depthm) AS StationCount, Bottle.Depthm AS Depth, Avg(Bottle.T_degC) AS Temp, Avg(Bottle.Salnty) AS Sal, Avg(Bottle.STheta) AS STheta, Avg(Nuts.PO4uM) AS Phosphate, Avg(Nuts.SiO3uM) AS Silicate, Avg(Nuts.NO2uM) AS Nitrite, Avg(Nuts.NO3uM) AS Nitrate, Avg(Bottle.O2ml_L) AS O2, [Nitrate]/[Phosphate] AS [N-P Ratio], [Nitrate]/[Silicate] AS [N-Si Ratio], [Phosphate]/[Silicate] AS [P-Si Ratio], [Sal]/[O2] AS [Sal-O2 Ratio]
FROM Cruises INNER JOIN ((Station_ID INNER JOIN Cast ON Station_ID.DBSta_ID = Cast.DbSta_ID) INNER JOIN (Bottle INNER JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Cruises.[Code-ST])="st") AND ((Station_ID.St_Line) Between 80 And 90) AND ((Station_ID.St_Sta) Between 50 And 120) AND ((Bottle.Depthm)=500) AND ((Bottle.RecInd)=7))
GROUP BY Cast.Year, Cast.Cruise, Bottle.Depthm, Station_ID.Sta_Code
HAVING (((Cast.Year)>1983) AND ((Station_ID.Sta_Code)="st"));
