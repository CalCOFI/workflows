-- query: UQ_AppendTo_DIC
-- type:  APPEND
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

INSERT INTO DICs (ID, Cruise, Btl_Cnt, StaPr, Depthm, Depth_ID, Sta_ID, pH1, pH2, DIC1, DIC2, TA1, TA2, Salinity1, Salinity2, Bottle_ID2, Niskin)
SELECT [1507DIC_DB].ID, [1507DIC_DB].Cruise, [1507DIC_DB].Btl_Cnt, [1507DIC_DB].StaPr, [1507DIC_DB].Depthm, [1507DIC_DB].Depth_ID, [1507DIC_DB].Sta_ID, [1507DIC_DB].pH1, [1507DIC_DB].pH2, [1507DIC_DB].DIC1, [1507DIC_DB].DIC2, [1507DIC_DB].TA1, [1507DIC_DB].TA2, [1507DIC_DB].Salinity1, [1507DIC_DB].Salinity2, [1507DIC_DB].Bottle_ID2, [1507DIC_DB].D_Nisk1
FROM 1507DIC_DB;
