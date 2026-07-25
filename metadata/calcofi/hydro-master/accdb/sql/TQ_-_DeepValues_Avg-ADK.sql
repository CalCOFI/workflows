-- query: TQ - DeepValues_Avg-ADK
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Cruise, Avg(Cast.Date) AS Date, Count(Bottle.Depthm) AS DepthCount, Avg(Bottle.Depthm) AS AvgDepth, Avg(Bottle.T_degC) AS Temp, Avg(Bottle.Salnty) AS Sal, Avg(Bottle.STheta) AS STheta, Avg(Nuts.PO4uM) AS PO4, Avg(Nuts.SiO3uM) AS SIO4, Avg(Nuts.NO2uM) AS NO2, Avg(Nuts.NO3uM) AS NO3, Avg(Bottle.O2ml_L) AS O2, [NO3]/[PO4] AS [N-P Ratio], [NO3]/[SiO4] AS [N-Si Ratio], [PO4]/[SiO4] AS [P-Si Ratio], [Sal]/[O2] AS [Sal-O2 Ratio], StDev(Nuts.PO4uM) AS StDevOfPO4ug, StDev(Nuts.SiO3uM) AS StDevOfSiO3ug, StDev(Nuts.NO2uM) AS StDevOfNO2ug, StDev(Nuts.NO3uM) AS StDevOfNO3ug, StDev(Bottle.Salnty) AS StDevOfSalnty, [NO3]/[Sal] AS [NO3-Sal], [PO4]/[Sal] AS [PO4-Sal], [SiO4]/[Sal] AS [Si-Sal], Avg(Cast.IntC14) AS AvgOfIntC14, Avg(Cast.IntChl) AS AvgOfIntChl
FROM Cruises INNER JOIN (Cast INNER JOIN (Bottle INNER JOIN (Chl INNER JOIN Nuts ON Chl.Btl_Cnt = Nuts.Btl_Cnt) ON (Bottle.Btl_Cnt = Nuts.Btl_Cnt) AND (Bottle.Btl_Cnt = Chl.Btl_Cnt)) ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Bottle.Depthm) Between 500 And 550) AND ((Cast.St_Station) Between 50 And 120) AND ((Cast.St_Line) Between 80 And 90))
GROUP BY Cast.Year, Cast.Cruise, Bottle.RecInd, Cast.Sta_Code, Cruises.[Code-ST]
HAVING (((Cast.Year)>1983) AND ((Count(Bottle.Depthm))>15) AND ((Bottle.RecInd)=3) AND ((Cast.Sta_Code)="st") AND ((Cruises.[Code-ST])="ST"));
