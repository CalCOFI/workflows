-- query: Line Station Coverage
-- type:  CROSS_TAB
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

TRANSFORM Count(Bottle.Depthm) AS NoDepths
SELECT Cast.Year, Cast.Cruise
FROM (St_Stations RIGHT JOIN Cast ON St_Stations.Sta_ID = Cast.Sta_ID) INNER JOIN (StDepths INNER JOIN Bottle ON StDepths.StDepth = Bottle.Depthm) ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((Cast.St_Line)=93.3) AND ((Cast.St_Station)<60))
GROUP BY Cast.Year, Cast.Cruise
PIVOT Cast.St_Station;
