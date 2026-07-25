-- query: UQ_Sta_ID_SBB_BottleTable
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Bottle
SET Bottle.Sta_ID = Replace([Sta_ID],"86.7 050.0","086.7 050.0")
WHERE (((Bottle.Sta_ID) Like "86.7 050.0") AND ((Bottle.Cst_Cnt)>32665));
