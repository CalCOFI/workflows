-- query: UQ-DepthID_PR
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Bottle
SET Bottle.Depth_ID = Replace([Depth_ID],"-PR-","-MX-")
WHERE (((Bottle.Depth_ID) Like "*-8410NM-PR-*") AND ((Bottle.Cst_Cnt)=23954));
