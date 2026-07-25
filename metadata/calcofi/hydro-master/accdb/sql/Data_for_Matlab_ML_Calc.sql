-- query: Data for Matlab ML Calc
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.CruiseAlias AS Cruise, Cast.Cast_ID, Cast.Sta_ID, Avg(Cast!Date+Cast!Time) AS DateTime, Bottle.Depthm AS Depth, Avg(Bottle.T_degC) AS Temp, Avg(Bottle.STheta) AS Density, Bottle.RecInd
FROM Cast INNER JOIN Bottle ON Cast.Cst_Cnt = Bottle.Cst_Cnt
GROUP BY Cast.Year, Cast.CruiseAlias, Cast.Cast_ID, Cast.Sta_ID, Bottle.Depthm, Bottle.RecInd
HAVING (((Cast.CruiseAlias)>201611) AND ((Bottle.Depthm)<300) AND ((Avg(Bottle.STheta)) Is Not Null) AND ((Bottle.RecInd)=3 Or (Bottle.RecInd)=5))
ORDER BY Cast.Cast_ID, Bottle.Depthm;
