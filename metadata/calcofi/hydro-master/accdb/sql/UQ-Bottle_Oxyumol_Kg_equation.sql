-- query: UQ-Bottle_Oxyumol/Kg_equation
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast INNER JOIN Bottle ON Cast.Cst_Cnt = Bottle.Cst_Cnt
SET Bottle.[Oxy_µmol/Kg] = (([Bottle].[O2ml_L]*44660)/([Bottle].[STheta]+1000))
WHERE (((Cast.Cruise)=201604) AND ((Bottle.O2ml_L) Is Not Null));
