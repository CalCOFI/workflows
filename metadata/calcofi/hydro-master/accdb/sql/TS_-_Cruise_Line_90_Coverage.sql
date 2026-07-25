-- query: TS - Cruise: Line 90 Coverage
-- type:  CROSS_TAB
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

TRANSFORM Count(Bottle.Depthm) AS CountOfDepthm
SELECT Cruises.Cruise, Cast.St_Line, Avg(Cast.Date) AS AvgOfDate
FROM Cruises INNER JOIN ((Station_ID INNER JOIN Cast ON Station_ID.Sta_ID = Cast.Sta_ID) INNER JOIN Bottle ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Cast.St_Line)=93.3) AND ((Station_ID.Sta_Code)="st") AND ((Bottle.RecInd)=3))
GROUP BY Cruises.Cruise, Cast.St_Line, Bottle.RecInd
ORDER BY Cruises.Cruise
PIVOT Cast.St_Station;
