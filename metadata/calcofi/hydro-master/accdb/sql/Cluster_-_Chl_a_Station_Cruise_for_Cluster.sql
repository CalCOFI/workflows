-- query: Cluster - Chl a: Station_Cruise for Cluster
-- type:  CROSS_TAB
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

TRANSFORM Avg(Chl.ChlorA) AS AvgOfChlorA
SELECT Cast.DbSta_ID, Station_ID.DLat_Dec, Station_ID.DLon_Dec
FROM Cruises INNER JOIN ((((Station_ID INNER JOIN Cast ON Station_ID.DBSta_ID = Cast.DbSta_ID) INNER JOIN MLD_Sigma ON Cast.Cast_ID = MLD_Sigma.Cast_ID) LEFT JOIN NutClineDepth ON Cast.Cast_ID = NutClineDepth.Cast_ID) INNER JOIN ((Bottle LEFT JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Station_ID.Sta_Code)="st") AND ((Cruises.[Code-ST])="st") AND ((Bottle.Depthm)>[MLD_Sigma]![MLD_Sigma]) AND ((Bottle.RecInd)=3) AND ((Cruises.Cruise)>198400))
GROUP BY Cast.DbSta_ID, Station_ID.DLat_Dec, Station_ID.DLon_Dec
PIVOT Cast.Cruise;
