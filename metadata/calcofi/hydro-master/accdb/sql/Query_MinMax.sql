-- query: Query_MinMax
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Cruise, Min(Bottle.Salnty) AS MinOfSalnty, Max(Bottle.Salnty) AS MaxOfSalnty, Min(Bottle.O2ml_L) AS MinOfO2ml_L, Max(Bottle.O2ml_L) AS MaxOfO2ml_L, Min(Nuts.PO4uM) AS MinOfPO4ug, Max(Nuts.PO4uM) AS MaxOfPO4ug, Min(Nuts.SiO3uM) AS MinOfSiO3ug, Max(Nuts.SiO3uM) AS MaxOfSiO3ug, Min(Nuts.NO2uM) AS MinOfNO2ug, Max(Nuts.NO2uM) AS MaxOfNO2ug, Min(Nuts.NO3uM) AS MinOfNO3ug, Max(Nuts.NO3uM) AS MaxOfNO3ug, Min(Nuts.NH3uM) AS MinOfNH3ug, Max(Nuts.NH3uM) AS MaxOfNH3ug, Min(Chl.ChlorA) AS MinOfChlorA, Max(Chl.ChlorA) AS MaxOfChlorA, Min(Chl.Phaeop) AS MinOfPhaeop, Max(Chl.Phaeop) AS MaxOfPhaeop
FROM Cast INNER JOIN ((Bottle LEFT JOIN Chl ON Bottle.Btl_Cnt = Chl.Btl_Cnt) LEFT JOIN Nuts ON Bottle.Btl_Cnt = Nuts.Btl_Cnt) ON Cast.Cst_Cnt = Bottle.Cst_Cnt
GROUP BY Cast.Cruise
HAVING (((Cast.Cruise)>198310))
ORDER BY Cast.Cruise, Max(Bottle.Salnty), Min(Bottle.O2ml_L), Max(Bottle.O2ml_L), Min(Nuts.PO4uM), Max(Nuts.PO4uM), Min(Nuts.SiO3uM), Max(Nuts.SiO3uM), Min(Nuts.NO2uM), Max(Nuts.NO2uM), Min(Nuts.NO3uM), Max(Nuts.NO3uM), Min(Nuts.NH3uM), Max(Nuts.NH3uM), Min(Chl.ChlorA), Max(Chl.ChlorA), Min(Chl.Phaeop), Max(Chl.Phaeop);
