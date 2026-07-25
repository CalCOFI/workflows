-- query: Isopycnal Properties - 1 Station
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Bottle_Sigm.Sta_ID, Cast.Year, Avg(Year(Cast!Date)+Month(Cast!Date)/12+Day(Cast!Date)/365) AS YearValue, Cast.Cruise, Avg(Cast.Date) AS Date, Avg(Cast!Month+Day(Cast!Date)/31.5-1) AS Month, Count(Bottle_Sigm.Depth) AS StCount, Avg(Bottle_Sigm.STheta) AS STheta, Avg(Bottle_Sigm.Depth) AS Depth, Avg(Bottle_Sigm.Temp) AS Temp, Avg(Bottle_Sigm.Sal) AS Sal, Avg(Bottle_Sigm.PO4) AS PO4, Avg(Bottle_Sigm.SiO4) AS SiO4, Avg(Bottle_Sigm.NO3) AS NO3, Avg(Bottle_Sigm.NO2) AS NO2, Avg(Bottle_Sigm.O2) AS O2, Avg(Bottle_Sigm.O2Sat) AS O2Sat, ([NO3]/[PO4]) AS [N-P_Ratio], ((([NO3]-16*[PO4]+2.9))) AS [N-Star]
FROM Cruises INNER JOIN (St_Stations INNER JOIN (Cast INNER JOIN Bottle_Sigm ON Cast.Cast_ID = Bottle_Sigm.Cast_ID) ON St_Stations.Sta_ID = Cast.Sta_ID) ON Cruises.Cruise = Cast.Cruise
WHERE (((Bottle_Sigm.STheta) Between 26 And 26.4) AND ((Cruises.[Code-ST])="ST"))
GROUP BY Bottle_Sigm.Sta_ID, Cast.Year, Cast.Cruise
HAVING (((Bottle_Sigm.Sta_ID)="093.3 030.0") AND ((Cast.Year)>1983))
ORDER BY Bottle_Sigm.Sta_ID, Cast.Cruise, Avg(Bottle_Sigm.STheta);
