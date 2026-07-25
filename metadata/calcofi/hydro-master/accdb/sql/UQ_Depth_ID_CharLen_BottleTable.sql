-- query: UQ_Depth_ID_CharLen_BottleTable
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Bottle
SET Bottle.Depth_ID = Replace([Depth_ID],"-800505","-08000505")
WHERE (((Bottle.Depth_ID) Like "*-800505*") AND ((Bottle.Cst_Cnt)>32423));
