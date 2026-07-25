-- query: UQ_Table2Table_Bottle_To_DIC
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast INNER JOIN (Bottle INNER JOIN DICs ON Bottle.Sta_ID = DICs.Sta_ID) ON (Cast.Cst_Cnt = Bottle.Cst_Cnt) AND (Cast.Cruise = DICs.Cruise)
SET DICs.Depth_ID = [Bottle].[Depth_ID], DICs.Btl_Cnt = [Bottle].[Btl_Cnt]
WHERE (((Cast.Cruise)=201402) AND ((Cast.Cst_Cnt)<>33468) AND ((DICs.Niskin)=[Bottle].[BtlNum]) AND ((DICs.Sta_ID)=[Bottle].[Sta_ID]));
