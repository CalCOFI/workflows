-- query: UQ_Table2Table_Bottle_To_DIC_csv
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE (1507DIC_DB INNER JOIN Cast ON [1507DIC_DB].Cruise = Cast.Cruise) INNER JOIN Bottle ON (Cast.Cst_Cnt = Bottle.Cst_Cnt) AND ([1507DIC_DB].Sta_ID = Bottle.Sta_ID)
SET [1507DIC_DB].Depth_ID = [Bottle].[Depth_ID], [1507DIC_DB].Btl_Cnt = [Bottle].[Btl_Cnt]
WHERE ((([1507DIC_DB].StaNisk)=[Bottle].[BtlNum]) AND ((Cast.Cruise)=201507) AND (([1507DIC_DB].Sta_ID)=[Bottle].[Sta_ID]));
