-- query: UQ_StaName
-- type:  UPDATE
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

UPDATE Cast
SET Cast.St_Station = Replace([St_Station],"47","46.9")
WHERE (((Cast.St_Station) Like "*47") AND ((Cast.Year)>2008));
