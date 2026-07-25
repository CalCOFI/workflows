-- query: SBB O2 below 560m
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Month, Cast.Date, Cast.St_Line, Cast.St_Station, Bottle.Depthm, Bottle.T_degC, Bottle.Salnty, Bottle.[Oxy_µmol/Kg], Bottle.O2ml_L
FROM (Cruises INNER JOIN Cast ON Cruises.Cruise = Cast.Cruise) INNER JOIN Bottle ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((Cast.St_Station)=46.9) AND ((Bottle.Depthm)>560) AND ((Bottle.O2ml_L) Is Not Null));
