-- query: UQ-CruiseAlias
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast
SET Cast.CruiseAlias = [cast].[Cruise]
WHERE (((Cast.Cruise)=202304));
