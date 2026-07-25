-- query: RS Deep basin O2
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT Cast.Year, Cast.Month, Cast.St_Line, Cast.St_Station, Bottle.Depthm, Bottle.T_degC, Bottle.Salnty, Bottle.O2ml_L, Bottle.BtlNum
FROM Cruises INNER JOIN (Cast INNER JOIN Bottle ON Cast.Cst_Cnt = Bottle.Cst_Cnt) ON Cruises.Cruise = Cast.Cruise
WHERE (((Cast.St_Line)=86.7) AND ((Cast.St_Station)=40) AND ((Bottle.BtlNum)=1)) OR (((Cast.St_Line)=81.8) AND ((Cast.St_Station)=46.9) AND ((Bottle.BtlNum)=1));
