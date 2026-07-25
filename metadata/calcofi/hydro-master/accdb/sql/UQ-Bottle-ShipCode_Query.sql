-- query: UQ-Bottle-ShipCode Query
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast INNER JOIN Bottle ON Cast.Cst_Cnt = Bottle.Cst_Cnt
SET Bottle.Depth_ID = Left([Depth_ID],7)+Right([Ship_Code],2)+Right([Depth_ID],29)
WHERE (((InStr([Bottle].[Depth_ID],Right([Cast].[Ship_Code],2)))="0"));
