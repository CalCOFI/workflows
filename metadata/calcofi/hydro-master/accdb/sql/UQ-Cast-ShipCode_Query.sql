-- query: UQ-Cast-ShipCode Query
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast
SET Cast.Cast_ID = Left([Cast_ID],7)+Right([Ship_Code],2)+Right([Cast_ID],21)
WHERE (((InStr([Cast_ID],Right([Ship_Code],2)))="0"));
