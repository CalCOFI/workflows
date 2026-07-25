-- query: UQ-CruiseAlias_Zoop
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Zooplankton
SET Zooplankton.CruiseAlias = [Zooplankton].[Cruise]
WHERE (((Zooplankton.Cruise)=201802));
