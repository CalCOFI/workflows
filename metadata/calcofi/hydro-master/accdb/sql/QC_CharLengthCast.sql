-- query: QC_CharLengthCast
-- type:  SELECT
-- source: CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb (ACE12), extracted via Jackcess

SELECT *
FROM Cast
WHERE (((Len([Cast_ID]))<30));
