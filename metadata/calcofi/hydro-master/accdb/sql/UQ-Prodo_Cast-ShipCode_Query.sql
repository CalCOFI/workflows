-- query: UQ-Prodo_Cast-ShipCode Query
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast INNER JOIN Prodo_Cast ON Cast.Cst_Cnt = Prodo_Cast.Cst_Cnt
SET Prodo_Cast.Cast_ID = Left(Prodo_Cast.Cast_ID,7)+Right(Cast.Ship_Code,2)+Right(Prodo_Cast.Cast_ID,21)
WHERE (((InStr([Prodo_Cast].[Cast_ID],Right([Cast].[Ship_Code],2)))="0"));
