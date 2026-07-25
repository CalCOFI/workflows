-- query: UQ-Cruise_ID_new
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast, Cast1
SET Cast.Ship_Code = Cast1.Ship_Code
WHERE (((Cast.Ship_Code)<>[Cast1].[Ship_Code]));
