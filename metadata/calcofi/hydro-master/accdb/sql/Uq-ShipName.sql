-- query: Uq-ShipName
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE [0-Ships] INNER JOIN Cast ON [0-Ships].Ship_Code = Cast.Ship_Code
SET Cast.Ship_Name = [0-Ships].Ship_Name
WHERE (((Cast.Ship_Name)<>[0-Ships].[Ship_Name]));
