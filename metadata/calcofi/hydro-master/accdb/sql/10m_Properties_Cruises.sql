-- query: 10m Properties Cruises
-- type:  CROSS_TAB
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

TRANSFORM Avg(Bottle.STheta) AS AvgOfSTheta
SELECT Cast.Cruise, Station_ID.St_Sta
FROM Cruises INNER JOIN ((Station_ID INNER JOIN Cast ON Station_ID.DBSta_ID = Cast.DbSta_ID) INNER JOIN ((Bottle LEFT JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Cast.Cruise)=200701) AND ((Station_ID.Sta_Code)="st") AND ((Cruises.[Code-ST])="st") AND ((Bottle.Depthm)=10))
GROUP BY Cast.Cruise, Station_ID.St_Sta
PIVOT Station_ID.St_Line;
