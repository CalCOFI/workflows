-- query: TV - Chl Value Tests
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, Cast.Sta_ID, Bottle.Depthm, Chl.ChlorA, Chl.Phaeop, [ChlorA]/([Phaeop]+0.0001) AS [Chl-Pheo Ratio]
FROM Cast INNER JOIN (Bottle INNER JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((Cast.St_Station)>50))
GROUP BY Cast.Cruise, Cast.Sta_ID, Bottle.Depthm, Chl.ChlorA, Chl.Phaeop
HAVING (((Bottle.Depthm)<21) AND ((Chl.ChlorA) Is Not Null) AND ((Chl.Phaeop)>0) AND (([ChlorA]/([Phaeop]+0.0001))<1))
ORDER BY [ChlorA]/([Phaeop]+0.0001);
