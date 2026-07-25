-- query: UQ-Ship_Code
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast INNER JOIN [0-Ships] ON Cast.Ship_Code = [0-Ships].Ship_Code
SET Cast.Ship_Name = [0-Ships].Ship_Name
WHERE (((Cast.Ship_Name)<>[0-Ships].[Ship_Name]) AND ((Cast.Ship_Code)=[0-Ships].[Ship_Code]));
